# RM — Implementation Progress

**Proje:** ReplaceMe (RM)  
**Platform:** macOS 13+, Swift 5.9, AppKit  
**Başlangıç:** 2026-03-04

---

## Genel Durum

| Bileşen | Durum | Notlar |
|---------|-------|--------|
| PRD | ✅ Tamamlandı | `plans/PRD.md` |
| Architecture Blueprint | ✅ Tamamlandı | `plans/ARCHITECTURE.md` |
| Proje İskeleti | ⬜ Bekliyor | SwiftUI default template mevcut |
| AppDelegate + LSUIElement | ⬜ Bekliyor | |
| Infrastructure: InputManager | ⬜ Bekliyor | |
| Infrastructure: EventInjector | ⬜ Bekliyor | |
| Infrastructure: AccessibilityChecker | ⬜ Bekliyor | |
| Domain: ReplaceEngine (actor) | ⬜ Bekliyor | |
| Domain: WordBuffer | ⬜ Bekliyor | |
| Domain: ReplaceAction | ⬜ Bekliyor | |
| Data: DictionaryStore (actor) | ⬜ Bekliyor | |
| Data: SettingsStore | ⬜ Bekliyor | |
| Data: CSVService | ⬜ Bekliyor | |
| UI: StatusBarController | ⬜ Bekliyor | |
| UI: SettingsWindowController | ⬜ Bekliyor | |
| UI: AddWordPopupController | ⬜ Bekliyor | |
| UI: ServiceHandler (NSServices) | ⬜ Bekliyor | |
| Info.plist: LSUIElement + NSServices | ⬜ Bekliyor | |
| Entitlements: Sandbox kapalı | ⬜ Bekliyor | |
| Unit Tests: ReplaceEngine | ⬜ Bekliyor | |
| Unit Tests: WordBuffer | ⬜ Bekliyor | |
| Unit Tests: DictionaryStore | ⬜ Bekliyor | |
| Unit Tests: CSVService | ⬜ Bekliyor | |
| Acceptance Tests: Manuel | ⬜ Bekliyor | AC-01 → AC-10 |

---

## Sprint 1 — Foundation

**Hedef:** Çalışan uygulama iskeleti + Infrastructure katmanı

### Görevler

- [ ] **TASK-01** — Xcode proje yapısı yeniden düzenle  
  SwiftUI template'i AppKit AppDelegate tabanlıya dönüştür.  
  `LSUIElement = YES` set et. Dock'ta uygulama görünmemeli.

- [ ] **TASK-02** — Entitlements düzelt  
  App Sandbox'ı kapat. `com.apple.security.app-sandbox = false`

- [ ] **TASK-03** — `AccessibilityChecker` implement et  
  `AXIsProcessTrusted()` kontrolü + System Preferences yönlendirmesi.

- [ ] **TASK-04** — `EventInjector` implement et  
  CGEventSource oluştur, backspace + unicode string inject, RM_EVENT_TAG işaretleme.

- [ ] **TASK-05** — `InputManager` implement et  
  CGEventTap kurulum, callback, RM_EVENT_TAG bypass, pasif mod bypass.

---

## Sprint 2 — Domain & Data

**Hedef:** Replace mantığı + Persistence

### Görevler

- [ ] **TASK-06** — `WordBuffer` implement et  
  Append, flush, clear, backspace handling.

- [ ] **TASK-07** — `ReplaceAction` enum tanımla

- [ ] **TASK-08** — `DictionaryStore` (actor) implement et  
  JSON yükleme/kaydetme, CRUD operations, debounced save.

- [ ] **TASK-09** — `SettingsStore` implement et  
  UserDefaults wrapper, thread-safe cached properties.

- [ ] **TASK-10** — `ReplaceEngine` (actor) implement et  
  Letter replace logic, word replace logic, buffer reset kuralları.

- [ ] **TASK-11** — `InputManager` ↔ `ReplaceEngine` entegrasyonu  
  Callback → ReplaceEngine.process() → action → EventInjector.

---

## Sprint 3 — UI Layer

**Hedef:** Menubar UI + Settings + Popup

### Görevler

- [ ] **TASK-12** — `StatusBarController` implement et  
  NSStatusItem, ikon durumu, sol tık toggle, dropdown menu.

- [ ] **TASK-13** — `SettingsWindowController` + `SettingsViewController` implement et  
  İki NSTextView (letter/word), parse → DictionaryStore, Save butonu.

- [ ] **TASK-14** — `CSVService` implement et  
  Import (NSSavePanel / NSOpenPanel), export, CSV parse/serialize.

- [ ] **TASK-15** — CSV butonlarını Settings'e bağla  
  Import → DictionaryStore güncelle → textview yenile.  
  Export → mevcut kuralları dışa yaz.

- [ ] **TASK-16** — `AddWordPopupController` implement et  
  NSPanel, word/replacement field, Add → DictionaryStore.

---

## Sprint 4 — Services & Polish

**Hedef:** NSServices entegrasyonu, kabul testleri, edge case'ler

### Görevler

- [ ] **TASK-17** — Info.plist `NSServices` girişi ekle

- [ ] **TASK-18** — `ServiceHandler` implement et  
  `addToRMDictionary:userData:error:` selector, popup göster.

- [ ] **TASK-19** — Buffer reset: focus değişimi, Escape, Backspace  
  `NSWorkspace.didActivateApplicationNotification` ile buffer temizle.

- [ ] **TASK-20** — CGEventTap disable detection  
  `kCGEventTapDisabledByTimeout` / `kCGEventTapDisabledByUserInput` handle et,  
  otomatik re-enable veya kullanıcıya uyarı.

- [ ] **TASK-21** — Unit testler  
  ReplaceEngine, WordBuffer, DictionaryStore, CSVService.

- [ ] **TASK-22** — Manuel Acceptance testler (AC-01 → AC-10)

---

## Kararlar & Notlar

| Tarih | Karar | Gerekçe |
|-------|-------|---------|
| 2026-03-04 | AppKit seçildi, SwiftUI değil | CGEventTap + NSStatusBar entegrasyonu |
| 2026-03-04 | App Sandbox kapalı | CGEventTap sistem iznine ihtiyaç duyar |
| 2026-03-04 | Persistence: JSON (Application Support) | Basit, okunabilir, versiyonlanabilir |
| 2026-03-04 | Actor isolation: ReplaceEngine + DictionaryStore | Thread safety + Swift Concurrency uyumu |
| 2026-03-04 | RM_EVENT_TAG ile sonsuz döngü koruması | Kendi inject ettiğimiz event'leri bypass et |
| 2026-03-04 | CGEventTap callback'te async yok | Callback < 2ms dönmeli, macOS timeout riski |

---

## Risk Kayıtları

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| CGEventTap timeout (macOS disable) | Orta | Kritik | Re-enable mekanizması + kullanıcı uyarısı |
| Accessibility izni macOS güncellemesinde sıfırlanma | Düşük | Yüksek | Her launch'ta kontrol |
| Services menüsü re-login gerektiriyor | Orta | Orta | `NSUpdateDynamicServices()` + dokümantasyon |
| Bazı uygulamalarda CGEventTap çalışmıyor (Secure Input) | Orta | Orta | Secure input detection + kullanıcıya bilgi |
| Emoji/multi-byte karakter inject sorunları | Düşük | Düşük | Unicode string inject yöntemi kullan |

---

## Referanslar

- [PRD](./PRD.md)
- [ARCHITECTURE](./ARCHITECTURE.md)
- [CGEventTap Apple Docs](https://developer.apple.com/documentation/coregraphics/cgeventtap)
- [NSServices Apple Docs](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/introduction.html)
- [AXIsProcessTrusted](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrusted)
