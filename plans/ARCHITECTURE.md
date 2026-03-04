# RM — Technical Architecture Blueprint

**Version:** 1.0  
**Architect:** SSA-SWIFT  
**Platform:** macOS 13+, Swift 5.9, AppKit

---

## Table of Contents

1. [Architecture Decision Records](#1-architecture-decision-records)
2. [System Context Diagram](#2-system-context-diagram)
3. [Module Architecture](#3-module-architecture)
4. [Data Layer](#4-data-layer)
5. [Concurrency Model](#5-concurrency-model)
6. [Keyboard Engine Design](#6-keyboard-engine-design)
7. [Replace Engine Design](#7-replace-engine-design)
8. [UI Layer Design](#8-ui-layer-design)
9. [Services Integration](#9-services-integration)
10. [Security & Permission Model](#10-security--permission-model)
11. [Testing Strategy](#11-testing-strategy)
12. [File & Directory Structure](#12-file--directory-structure)
13. [Open Questions](#13-open-questions)

---

## 1. Architecture Decision Records

### ADR-01: UI Framework — AppKit (not SwiftUI)

**Decision:** AppKit  
**Rationale:**
- `NSStatusBar`, `NSStatusItem`, `NSMenu` tam native API gerektiriyor.
- SwiftUI menubar desteği sınırlı (macOS 14'te iyileşti ama CGEventTap entegrasyonu ile birlikte karmaşıklaşıyor).
- Settings penceresi `NSTextView` ile satır bazlı düzenleme yapacak; SwiftUI `TextEditor` performans sorunları yaşıyor.
- AppKit AppDelegate tabanlı lifecycle, `LSUIElement` ile uyumlu.

**Tradeoff:** Daha fazla boilerplate, SwiftUI preview yok.

---

### ADR-02: Architecture Pattern — Clean Architecture (Input → Domain → Data)

**Katmanlar:**

```
┌─────────────────────────────────────────────────────────┐
│                     UI Layer (AppKit)                    │
│  StatusBarController · SettingsWindowController          │
│  AddWordPopupController · ServiceHandler                 │
└────────────────────┬────────────────────────────────────┘
                     │ protocol
┌────────────────────▼────────────────────────────────────┐
│                   Domain Layer                           │
│  ReplaceEngine · WordBuffer · ReplaceRule                │
└────────────────────┬────────────────────────────────────┘
                     │ protocol
┌────────────────────▼────────────────────────────────────┐
│                   Data Layer                             │
│  DictionaryStore · SettingsStore · CSVService            │
└─────────────────────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│               Infrastructure Layer                       │
│  InputManager (CGEventTap) · EventInjector               │
└─────────────────────────────────────────────────────────┘
```

**Rationale:** Replace mantığı UI'dan tamamen bağımsız olmalı → birim testleri CGEventTap olmadan çalışabilmeli.

---

### ADR-03: Concurrency Model — Actor + MainActor

- `InputManager` callback'i → private serial DispatchQueue (CGEventTap callback thread-safe değil).
- Domain logic (ReplaceEngine, WordBuffer) → `actor` ile izole.
- UI güncellemeleri → `@MainActor`.
- CGEventTap callback içinde async/await yok (callback return süresi kritik < 2ms); sadece senkron işlem + DispatchQueue.async ile actor'a gönder.

---

### ADR-04: Persistence — JSON (Application Support) + UserDefaults

- **Sözlük verileri:** `~/Library/Application Support/RM/dictionaries.json`
- **Format:** `{ "letterRules": [{"from":"a","to":"b"}], "wordRules": [{"from":"brb","to":"be right back"}] }`
- **Küçük ayarlar (aktiflik, mod bayrakları):** `UserDefaults` — `isGlobalActive`, `isLetterReplaceActive`, `isWordReplaceActive`.
- **Migration:** Versiyon alanı JSON'a eklenmeli, ileride schema değişikliğinde migrate edilebilsin.
- **Dosya erişimi:** FileManager ile senkron okuma (uygulama başlangıcında bir kez), senkron yazma (kullanıcı değiştirdiğinde). Actor koruması ile thread-safe.

---

## 2. System Context Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                          macOS Kernel                            │
│                                                                  │
│  ┌─────────────────┐        ┌──────────────────────────────┐    │
│  │   HID / IOKit   │──────▶│         CGEventTap            │    │
│  │  (Keyboard HW)  │        │  (Accessibility izni gerekli) │    │
│  └─────────────────┘        └──────────────┬───────────────┘    │
│                                            │ keyDown event       │
└────────────────────────────────────────────┼───────────────────-─┘
                                             │
                              ┌──────────────▼───────────────┐
                              │      RM Application           │
                              │                              │
                              │  InputManager                │
                              │  ├─ EventTapCallback         │
                              │  └─ EventInjector            │
                              │                              │
                              │  ReplaceEngine (actor)       │
                              │  ├─ LetterReplacer           │
                              │  └─ WordReplacer             │
                              │       └─ WordBuffer          │
                              │                              │
                              │  DictionaryStore (actor)     │
                              │  SettingsStore               │
                              │                              │
                              │  UI Layer                    │
                              │  ├─ StatusBarController      │
                              │  ├─ SettingsWindowCtrl       │
                              │  └─ AddWordPopupController   │
                              └──────────────────────────────┘
                                             │
                              ┌──────────────▼───────────────┐
                              │   ~/Library/Application      │
                              │   Support/RM/dictionaries.json│
                              └──────────────────────────────┘
```

---

## 3. Module Architecture

### 3.1 Infrastructure — InputManager

| Özellik | Detay |
|---------|-------|
| Sorumluluk | CGEventTap kurulumu, event yakalama, EventInjector |
| Public API | `start()`, `stop()`, `var isRunning: Bool` |
| Dahili Bağımlılıklar | `ReplaceEngine`, `SettingsStore` |
| Thread Safety | Callback private serial queue'da çalışır |
| Sonsuz Döngü Koruması | `CGEventSourceStateID.hidSystemState` ile oluşturulan kendi event'leri `kCGEventSourceUserData` tag ile işaretlenir; callback'te tag kontrol edilir |

```swift
// Pseudo API
final class InputManager {
    static let shared = InputManager()
    
    func start() throws   // Accessibility kontrolü + tap kur
    func stop()           // Tap kaldır
    var isRunning: Bool
    
    // Internal
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let processingQueue = DispatchQueue(label: "com.rm.input", qos: .userInteractive)
}
```

**CGEventTap Callback Pattern:**

```swift
// C-style callback — no captures, use Unmanaged
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown else { return Unmanaged.passRetained(event) }
    
    // 1. Kendi enjekte ettiğimiz event mi? → bypass
    guard event.getIntegerValueField(.eventSourceUserData) != RM_EVENT_TAG else {
        return Unmanaged.passRetained(event)
    }
    
    // 2. Motor pasif mi? → bypass
    guard SettingsStore.shared.isGlobalActive else {
        return Unmanaged.passRetained(event)
    }
    
    // 3. Event'i işle (senkron, < 2ms)
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let character = event.character() // extension
    
    // 4. ReplaceEngine'e gönder (actor, async — ama callback sync dönmeli)
    // Pattern: event'i tut, async işlem başlat, sonucu EventInjector ile uygula
    // Strateji: Callback'te event'i iptal et, işlemi queue'ya at, sonuç gelince inject et
    
    return nil // event'i yut, injector halleder
}
```

> **Kritik Not:** CGEventTap callback'i `Unmanaged<CGEvent>?` döndürmeli. `nil` döndürmek event'i iptal eder. Çok uzun süren işlem (> ~50ms) CGEventTap'i macOS tarafından disable edilmesine yol açar. Bu nedenle callback mümkün olduğunca hızlı dönmeli; ağır işlemler asenkron yapılmamalı, sadece basit sözlük lookup'ı yapılmalıdır.

---

### 3.2 Infrastructure — EventInjector

| Özellik | Detay |
|---------|-------|
| Sorumluluk | Sentetik backspace ve karakter event'i üretme |
| Public API | `inject(character: Character)`, `sendBackspaces(count: Int)` |
| Tag Mekanizması | Her event `kCGEventSourceUserData = RM_EVENT_TAG` ile işaretlenir |

```swift
// Event source — her injector instance için bir kez oluşturulur
let source = CGEventSource(stateID: .hidSystemState)
source?.setLocalEventsFilterDuringSuppressionState(.permitLocalMouseEvents, 
                                                    state: .eventSuppressionStateSuppressionInterval)

// Backspace inject
func sendBackspaces(count: Int) {
    for _ in 0..<count {
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)
        keyDown?.setIntegerValueField(.eventSourceUserData, value: RM_EVENT_TAG)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        // keyUp da gönder
    }
}

// Karakter inject — Unicode string yöntemi (virtual key bağımsız)
func inject(string: String) {
    let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
    event?.keyboardSetUnicodeString(stringLength: string.utf16.count, 
                                     unicodeString: Array(string.utf16))
    event?.setIntegerValueField(.eventSourceUserData, value: RM_EVENT_TAG)
    event?.post(tap: .cgAnnotatedSessionEventTap)
}
```

---

### 3.3 Domain — ReplaceEngine

| Özellik | Detay |
|---------|-------|
| Sorumluluk | Letter replace ve word replace iş kuralları |
| Public API | `func process(character: Character, keyCode: Int64) -> ReplaceAction` |
| Actor İzolasyonu | `actor ReplaceEngine` |
| Bağımlılıklar | `DictionaryStore` (read-only lookup) |

```swift
enum ReplaceAction {
    case passthrough                          // Müdahale etme
    case replaceCharacter(String)            // Bu karakteri enjekte et
    case replaceWord(delete: Int, insert: String) // N backspace + string enjekte et
    case bufferOnly                          // Sadece buffer'a ekle, enjeksiyon yok
}

actor ReplaceEngine {
    private var wordBuffer = WordBuffer()
    private let settings: SettingsStore
    private let dictionary: DictionaryStore
    
    func process(character: Character, keyCode: Int64) -> ReplaceAction {
        // Letter replace önce kontrol edilir
        if settings.isLetterReplaceActive,
           let replacement = dictionary.letterReplacement(for: character) {
            return .replaceCharacter(replacement)
        }
        
        // Word replace
        if settings.isWordReplaceActive {
            if isWordTerminator(character, keyCode: keyCode) {
                let word = wordBuffer.flush()
                if let replacement = dictionary.wordReplacement(for: word) {
                    return .replaceWord(delete: word.count, insert: replacement)
                }
                return .passthrough
            } else {
                wordBuffer.append(character)
                return .bufferOnly // sadece buffer, event geç
            }
        }
        
        return .passthrough
    }
}
```

---

### 3.4 Domain — WordBuffer

```swift
struct WordBuffer {
    private var buffer: [Character] = []
    
    mutating func append(_ char: Character) {
        buffer.append(char)
    }
    
    mutating func flush() -> String {
        let word = String(buffer)
        buffer.removeAll()
        return word
    }
    
    mutating func clear() {
        buffer.removeAll()
    }
    
    var current: String { String(buffer) }
}
```

**Word Terminator Karakterler:** Space (0x31), Return (0x24), Noktalama (`.`, `,`, `!`, `?`, `;`, `:`)

---

### 3.5 Data — DictionaryStore

```swift
actor DictionaryStore {
    private(set) var letterRules: [String: String] = [:]  // from → to
    private(set) var wordRules:   [String: String] = [:]  // from → to
    
    // Persistence
    func load() throws     // JSON'dan yükle
    func save() throws     // JSON'a yaz (debounced, 500ms)
    
    // Mutations
    func setLetterRule(from: String, to: String)
    func setWordRule(from: String, to: String)
    func removeLetterRule(from: String)
    func removeWordRule(from: String)
    func replaceAllWordRules(_ rules: [String: String])
    func replaceAllLetterRules(_ rules: [String: String])
    
    // Lookups (synchronous in actor context)
    func letterReplacement(for char: Character) -> String?
    func wordReplacement(for word: String) -> String?
}
```

**JSON Schema:**

```json
{
  "version": 1,
  "letterRules": [
    { "from": "a", "to": "â" }
  ],
  "wordRules": [
    { "from": "brb", "to": "be right back" }
  ]
}
```

**Dosya Yolu:**

```swift
func dictionaryFileURL() -> URL {
    let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return appSupport
        .appendingPathComponent("RM", isDirectory: true)
        .appendingPathComponent("dictionaries.json")
}
```

---

### 3.6 Data — SettingsStore

```swift
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    @AppStorage("isGlobalActive")       var isGlobalActive: Bool = true
    @AppStorage("isLetterReplaceActive") var isLetterReplaceActive: Bool = true
    @AppStorage("isWordReplaceActive")   var isWordReplaceActive: Bool = true
    
    // CGEventTap'in bu değerleri senkron okuması için thread-safe cache:
    private(set) var isGlobalActiveCached: Bool = true
    // ... (UserDefaults KVO ile güncellenir)
}
```

> **Not:** CGEventTap callback'i main thread'den farklı thread'de çalışabilir. `@AppStorage` değerlerini doğrudan callback'te okumak yerine, her değişimde bir `AtomicBool` veya `os_unfair_lock` ile korunan cache tutulur.

---

### 3.7 Data — CSVService

```swift
struct CSVService {
    /// "kelime,replace\nkelime2,replace2" → [from: to]
    static func parse(_ content: String) -> [String: String]
    
    /// [from: to] → "kelime,replace\n..."
    static func serialize(_ rules: [String: String]) -> String
    
    /// Panel aç, dosya seç, parse et
    static func importRules(completion: @escaping ([String: String]) -> Void)
    
    /// Panel aç, dosya yaz
    static func exportRules(_ rules: [String: String])
}
```

---

## 4. Data Layer

### 4.1 JSON Persistence

- **Encoding:** `JSONEncoder` ile `Codable` struct.
- **Write:** Atomic write (`Data.write(to:options:.atomic)`).
- **Debounce:** Yazma işlemi 500ms debounce ile yapılır (kullanıcı hızlı yazarken her tuşta disk yazımı engellenir).
- **Migration:** JSON root'ta `"version": Int` alanı; gelecek versiyonlarda migration function'ları zincir halinde.

### 4.2 UserDefaults

| Key | Type | Default | Açıklama |
|-----|------|---------|----------|
| `isGlobalActive` | Bool | true | Global motor durumu |
| `isLetterReplaceActive` | Bool | true | Harf replace modu |
| `isWordReplaceActive` | Bool | true | Kelime replace modu |

---

## 5. Concurrency Model

```
MainThread (UI)
│
├── StatusBarController → @MainActor
├── SettingsWindowController → @MainActor
│
│   [CGEventTap Callback Thread]
│   InputManager.callback
│   ├─ hızlı senkron lookup (cached dict)
│   └─ EventInjector.inject() → CGEvent.post()
│
│   [Actor: ReplaceEngine]
│   └─ WordBuffer state koruması
│
│   [Actor: DictionaryStore]
│   ├─ load() / save()
│   └─ rule lookup
```

**Kural 1:** CGEventTap callback'inde `await` kullanma. Senkron lookup için `DictionaryStore`'un son state'i bir `NSDictionary` (thread-safe okuma) olarak cache'lenir ve callback'te direkt okunur.

**Kural 2:** UI'dan DictionaryStore'a yazma `Task { await store.setWordRule(...) }` ile yapılır.

**Kural 3:** EventInjector her zaman CGEventTap callback thread'inden (veya `processingQueue`'dan) çağrılır; main thread'den çağrılmaz.

---

## 6. Keyboard Engine Design

### Akış Diyagramı

```
KeyDown Event (HW)
        │
        ▼
CGEventTap Callback
        │
        ├─[kendi event'imiz?]──────────────────▶ passRetained (bypass)
        │
        ├─[motor pasif?]───────────────────────▶ passRetained (bypass)
        │
        ▼
Character + KeyCode extract
        │
        ▼
ReplaceEngine.process(character, keyCode)
        │
        ├─ .passthrough ────────────────────────▶ passRetained
        │
        ├─ .replaceCharacter(str)
        │       └─ event nil döndür (yut)
        │           EventInjector.inject(str)
        │
        ├─ .replaceWord(delete: N, insert: str)
        │       └─ event nil döndür
        │           EventInjector.sendBackspaces(N)
        │           EventInjector.inject(str + terminator)
        │
        └─ .bufferOnly ─────────────────────────▶ passRetained
```

### Karakter Extraction

```swift
extension CGEvent {
    var character: Character? {
        var length: UniCharCount = 1
        var chars = [UniChar](repeating: 0, count: 4)
        self.keyboardGetUnicodeString(maxStringLength: 4, 
                                       actualStringLength: &length, 
                                       unicodeString: &chars)
        guard length > 0 else { return nil }
        return Character(String(utf16CodeUnits: Array(chars.prefix(Int(length))), encoding: .utf16))
    }
}
```

---

## 7. Replace Engine Design

### 7.1 Letter Replace Logic

```
Harf Replace Aktif?
      │ YES
      ▼
Dictionary lookup: from → to
      │ FOUND
      ▼
Orijinal event'i yut
Inject: to string
```

### 7.2 Word Replace Logic

```
Karakter word terminator mı?
      │ YES
      ▼
buffer.flush() → word
      │
      ▼
Dictionary lookup: word → replacement
      │ FOUND
      ▼
Inject: backspace × word.count
Inject: replacement
Inject: terminator character

      │ NOT FOUND
      ▼
Passthrough (terminator dahil)
```

### 7.3 Buffer Reset Kuralları

Buffer şu durumlarda temizlenir:
- Motor devre dışı bırakıldığında.
- Uygulama focus değiştiğinde (NSWorkspace `didActivateApplicationNotification`).
- Escape tuşuna basıldığında.
- Backspace ile manuel silme yapıldığında (buffer sondan 1 karakter sil).

---

## 8. UI Layer Design

### 8.1 AppDelegate

```swift
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Dock'ta görünme
        
        // Accessibility check
        AccessibilityChecker.requestIfNeeded()
        
        // Store yükle
        Task { try await DictionaryStore.shared.load() }
        
        // Menubar kur
        statusBarController = StatusBarController()
        
        // Event tap başlat
        try? InputManager.shared.start()
        
        // Services kaydet
        NSApp.servicesProvider = ServiceHandler.shared
    }
}
```

### 8.2 StatusBarController

```swift
final class StatusBarController {
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    
    // İkon durumu
    func updateIcon(active: Bool) {
        let name = active ? "keyboard.fill" : "keyboard"
        statusItem.button?.image = NSImage(systemSymbolName: name, 
                                           accessibilityDescription: nil)
        statusItem.button?.alphaValue = active ? 1.0 : 0.4
    }
    
    // Sol tık → toggle
    @objc func statusItemClicked() {
        SettingsStore.shared.isGlobalActive.toggle()
        updateIcon(active: SettingsStore.shared.isGlobalActive)
    }
}
```

**Menu Yapısı:**

```
[RM İkonu]
  ├── ✓ Active                        (toggle)
  ├── ─────────────────
  ├── [✓] Word Replace Active         (checkbox)
  ├── [✓] Letter Replace Active       (checkbox)
  ├── ─────────────────
  ├── Open Settings...                (SettingsWindow aç)
  ├── ─────────────────
  └── Quit RM
```

### 8.3 SettingsWindowController

`NSWindowController` + `NSViewController` tabanlı.

**Layout:**

```
┌─────────────────────────────────────────────────────┐
│  RM Settings                                    [x] │
├─────────────────────────────────────────────────────┤
│  Letter Replace                                      │
│  ┌───────────────────────────────────────────────┐  │
│  │ a,â                                           │  │
│  │ i,î                                           │  │
│  │ ...                                           │  │
│  └───────────────────────────────────────────────┘  │
│                                                      │
│  Word Replace                    [Import] [Export]   │
│  ┌───────────────────────────────────────────────┐  │
│  │ brb,be right back                             │  │
│  │ omw,on my way                                 │  │
│  │ ...                                           │  │
│  └───────────────────────────────────────────────┘  │
│                                      [Save]          │
└─────────────────────────────────────────────────────┘
```

**Text View Parse Akışı:**

```
NSTextView değişti (textDidChange)
        │
        ▼
Satırları split (newline)
        │
        ▼
Her satır: "from,to" format?
        │ YES
        ▼
DictionaryStore.setLetterRule / setWordRule
        │
        ▼
Auto-save (debounced 500ms)
```

### 8.4 AddWordPopupController

`NSPanel` kullanılır (key window olmak zorunda değil, floating).

```
┌─────────────────────────────────┐
│  Add to RM Dictionary           │
│                                 │
│  Word: [brb              ]      │
│  Replace with: [_________ ]     │
│                                 │
│               [Cancel] [Add]    │
└─────────────────────────────────┘
```

---

## 9. Services Integration

### Info.plist Girişi

```xml
<key>NSServices</key>
<array>
    <dict>
        <key>NSMenuItem</key>
        <dict>
            <key>default</key>
            <string>RM – Sözlüğe Ekle</string>
        </dict>
        <key>NSMessage</key>
        <string>addToRMDictionary</string>
        <key>NSPortName</key>
        <string>RM</string>
        <key>NSSendTypes</key>
        <array>
            <string>NSStringPboardType</string>
        </array>
    </dict>
</array>
```

### ServiceHandler

```swift
final class ServiceHandler: NSObject {
    static let shared = ServiceHandler()
    
    @objc func addToRMDictionary(_ pasteboard: NSPasteboard, 
                                  userData: String?, 
                                  error: AutoreleasingUnsafeMutablePointer<NSString?>?) {
        guard let selectedText = pasteboard.string(forType: .string),
              !selectedText.isEmpty else { return }
        
        DispatchQueue.main.async {
            AddWordPopupController.show(forWord: selectedText)
        }
    }
}
```

---

## 10. Security & Permission Model

### Accessibility İzni

```swift
struct AccessibilityChecker {
    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }
    
    static func requestIfNeeded() {
        guard !isGranted() else { return }
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // Kullanıcıya bilgilendirme göster
        showPermissionAlert()
    }
    
    static func openSystemPreferences() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }
}
```

### Infinite Loop Koruması

```swift
let RM_EVENT_TAG: Int64 = 0x524D5F524D // "RM_RM" ASCII

// Inject ederken:
event.setIntegerValueField(.eventSourceUserData, value: RM_EVENT_TAG)

// Callback'te:
if event.getIntegerValueField(.eventSourceUserData) == RM_EVENT_TAG {
    return Unmanaged.passRetained(event) // kendi event'imiz, bypass
}
```

### App Sandbox

**Devre dışı bırakılmalı.** Entitlements dosyası:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <!-- App Sandbox KAPALI — CGEventTap gereksinimi -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

---

## 11. Testing Strategy

### 11.1 Unit Tests — Domain Layer

```swift
// ReplaceEngineTests.swift
class ReplaceEngineTests: XCTestCase {
    func test_letterReplace_returnsCorrectAction() async {
        let store = MockDictionaryStore(letterRules: ["a": "â"])
        let engine = ReplaceEngine(dictionary: store, settings: MockSettings(letterActive: true))
        let action = await engine.process(character: "a", keyCode: 0)
        XCTAssertEqual(action, .replaceCharacter("â"))
    }
    
    func test_wordReplace_onTerminator_replacesWord() async { ... }
    func test_motor_passive_returnsPassthrough() async { ... }
    func test_bufferClearsOnEscape() async { ... }
}
```

### 11.2 Unit Tests — Data Layer

```swift
// DictionaryStoreTests.swift
class DictionaryStoreTests: XCTestCase {
    func test_persistenceRoundtrip() async throws { ... }
    func test_jsonMigration_v1ToV2() async throws { ... }
}

// CSVServiceTests.swift
class CSVServiceTests: XCTestCase {
    func test_parse_validCSV() { ... }
    func test_parse_malformedLines_skipped() { ... }
    func test_serialize_roundtrip() { ... }
}
```

### 11.3 Integration Tests — WordBuffer

```swift
// WordBufferTests.swift
func test_buffer_flushesOnSpace() { ... }
func test_buffer_clearsOnEscape() { ... }
```

### 11.4 Manual / Acceptance Tests

| Test | Adım | Beklenen |
|------|------|---------|
| AC-02 | Harf kuralı: a→b; TextEdit'e "a" yaz | "b" görünür |
| AC-03 | Kelime kuralı: brb→be right back; "brb " yaz | "be right back " görünür |
| AC-04 | Motor pasif; herhangi tuşa bas | Değişiklik yok |
| AC-09 | Enjeksiyon yap, callback tekrar tetiklenir mi? | Tetiklenmez |

---

## 12. File & Directory Structure

```
ReplaceMe/
├── App/
│   ├── AppDelegate.swift
│   └── Info.plist
│
├── Infrastructure/
│   ├── InputManager.swift          # CGEventTap kurulum
│   ├── EventInjector.swift         # Sentetik event üretimi
│   └── AccessibilityChecker.swift  # AXIsProcessTrusted
│
├── Domain/
│   ├── ReplaceEngine.swift         # Actor — iş kuralları
│   ├── WordBuffer.swift            # Struct — buffer yönetimi
│   ├── ReplaceAction.swift         # Enum — action tipi
│   └── ReplaceRule.swift           # Struct — kural modeli
│
├── Data/
│   ├── DictionaryStore.swift       # Actor — JSON persistence
│   ├── SettingsStore.swift         # UserDefaults wrapper
│   ├── CSVService.swift            # Import/export
│   └── Models/
│       └── DictionaryData.swift    # Codable schema
│
├── UI/
│   ├── StatusBar/
│   │   └── StatusBarController.swift
│   ├── Settings/
│   │   ├── SettingsWindowController.swift
│   │   └── SettingsViewController.swift
│   ├── Popup/
│   │   └── AddWordPopupController.swift
│   └── Services/
│       └── ServiceHandler.swift
│
├── Resources/
│   └── Assets.xcassets
│
└── Tests/
    ├── ReplaceEngineTests.swift
    ├── WordBufferTests.swift
    ├── DictionaryStoreTests.swift
    └── CSVServiceTests.swift
```

---

## 13. Open Questions

| # | Soru | Öneri |
|---|------|-------|
| OQ-01 | Modifier key (Shift, Option) ile üretilen karakterlerde harf replace nasıl davranır? | Modifier-agnostic: sadece unicode karakter bakılır |
| OQ-02 | Multi-character "from" (ör. "ae"→"æ") harf replace? | Buffer bazlı ek logic; v1'de tek karakter |
| OQ-03 | Emoji replacement? | Unicode string inject yöntemi emoji'yi destekler; v1'de test et |
| OQ-04 | Aynı kelime birden fazla kuralda çakışırsa? | İlk eşleşen kazanır (insertion order korunur) |
| OQ-05 | CGEventTap macOS güncellemesiyle devre dışı kalırsa? | NSWorkspace notification ile kontrol; `CFRunLoopSourceInvalidated` callback'i dinle |
| OQ-06 | Services re-login gerektiriyor mu? | İlk kurulumda `NSUpdateDynamicServices()` çağrısı yapılabilir |
