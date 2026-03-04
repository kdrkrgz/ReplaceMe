// InputManager.swift — CGEventTap kurulum, event yakalama, sonsuz döngü koruması

import CoreGraphics
import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "InputManager")

enum InputManagerError: Error {
    case accessibilityNotGranted
    case eventTapCreationFailed
}

final class InputManager {

    static let shared = InputManager()

    private(set) var isRunning = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Dedicated serial queue — CGEventTap callback buraya dispatch edilir
    private let processingQueue = DispatchQueue(label: "com.kadirkaragoz.ReplaceMe.input", qos: .userInteractive)

    // ReplaceEngine referansı — callback'te async await kullanılmaz,
    // bu nedenle engine'in son sözlük state'i cached snapshot üzerinden okunur.
    private let engine = ReplaceEngine.shared
    private let injector = EventInjector.shared
    private let settings = SettingsStore.shared

    private init() {}

    /// Engine'e hiç ulaşmaması gereken keycodes — ok tuşları, F-tuşları, medya tuşları, vb.
    /// Sayı tuşları (18-29) ve Escape (53) engine içinde karakter tipine göre zaten filtrelenir,
    /// ancak açıkça burada da belirtmek defense-in-depth sağlar.
    private static let bypassKeyCodes: Set<Int64> = [
        // Arrow keys
        123, 124, 125, 126,
        // Home, End, Page Up, Page Down
        115, 119, 116, 121,
        // F1–F12
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
        // F13–F20
        105, 107, 113, 106, 64, 79, 80, 90,
        // Help / Insert
        114,
        // Forward Delete
        117,
        // Num Lock / Clear
        71,
    ]

    // MARK: - Public API

    func start() throws {
        guard AccessibilityChecker.isGranted() else {
            throw InputManagerError.accessibilityNotGranted
        }
        guard !isRunning else { return }

        // C callback — self'i Unmanaged ile yakala (capture list yasak)
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            Unmanaged<InputManager>.fromOpaque(selfPtr).release()
            throw InputManagerError.eventTapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        self.isRunning = true

        // CGEventTap disable detection — timeout veya kullanıcı tarafından kapatıldığında
        startTapHealthMonitor()

        log.info("EventTap started successfully")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        log.info("EventTap stopped")
    }

    // MARK: - Tap Health Monitor (TASK-20)

    private func startTapHealthMonitor() {
        // Her 5 saniyede bir tap'in hâlâ aktif olup olmadığını kontrol et
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard let tap = self.eventTap else { timer.invalidate(); return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                log.warning("EventTap disabled — attempting re-enable")
                CGEvent.tapEnable(tap: tap, enable: true)
                if !CGEvent.tapIsEnabled(tap: tap) {
                    log.error("EventTap re-enable failed — Accessibility permission may have been revoked")
                    DispatchQueue.main.async {
                        self.showTapDisabledAlert()
                    }
                }
            }
        }
    }

    private func showTapDisabledAlert() {
        let alert = NSAlert()
        alert.messageText = "Keyboard Monitoring Disabled"
        alert.informativeText = "ReplaceMe's keyboard interception was disabled by macOS. This may happen if Accessibility permission was revoked. Please check System Settings → Privacy & Security → Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Dismiss")
        if alert.runModal() == .alertFirstButtonReturn {
            AccessibilityChecker.openPrivacySettings()
        }
    }

    // MARK: - Internal callback entry (called from C callback)

    fileprivate func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        // TASK-20: Tap disabled by timeout — re-enable
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            log.warning("EventTap disabled event received (type=\(type.rawValue)) — re-enabling")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        // 1. Kendi inject ettiğimiz event mi? → bypass (sonsuz döngü koruması)
        if event.getIntegerValueField(.eventSourceUserData) == RM_EVENT_TAG {
            return Unmanaged.passRetained(event)
        }

        // 2. Global motor pasif mi? → bypass
        guard settings.isGlobalActiveCached else {
            return Unmanaged.passRetained(event)
        }

        // 3. Modifier tuşlar (Cmd/Ctrl/Option) varsa bypass — kısayolları koru
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            return Unmanaged.passRetained(event)
        }

        // 4. Letter rules textview odakta ise bypass — kendi letter replace'i kuralı bozmayı önle.
        // Word textview veya başka bir alan odaktaysa replace çalışır (kullanıcı duplicate görebilir).
        // NSApp.isActive genel bypass'ı KALDIRILDI: modifier guard (step 3) kısayolları zaten korur.
        if settings.isEditingLetterRulesCached {
            return Unmanaged.passRetained(event)
        }

        // 5. Non-processable keycode'lar → engine'e hiç gitme (ok tuşları, F-tuşları, vb.)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if InputManager.bypassKeyCodes.contains(keyCode) {
            return Unmanaged.passRetained(event)
        }

        // 6. Karakteri extract et
        guard let character = event.rmCharacter else {
            return Unmanaged.passRetained(event)
        }

        // 7. ReplaceEngine'den senkron action al (cached snapshot — async yok)
        let action = engine.processSynchronous(character: character, keyCode: keyCode)

        switch action {
        case .passthrough:
            return Unmanaged.passRetained(event)

        case .bufferOnly:
            // Karakteri buffer'a ekledik, event'i geçir
            return Unmanaged.passRetained(event)

        case .replaceCharacter(let str):
            // Orijinal event'i yut, yerine inject et
            injector.inject(string: str)
            return nil

        case .replaceWord(let deleteCount, let insert, let terminator):
            // Orijinal (terminator) event'i yut
            injector.sendBackspaces(count: deleteCount)
            injector.inject(string: insert)
            if let t = terminator {
                injector.inject(string: String(t))
            }
            return nil
        }
    }
}

// MARK: - C-style CGEventTap Callback

/// C callback — captures yok, self Unmanaged userInfo üzerinden geliyor.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let ptr = userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<InputManager>.fromOpaque(ptr).takeUnretainedValue()
    return manager.handleEvent(proxy: proxy, type: type, event: event)
}

// MARK: - CGEvent Character Extension

extension CGEvent {
    /// KeyDown event'inden unicode karakter çıkar.
    var rmCharacter: Character? {
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        let utf16 = Array(chars.prefix(length))
        let scalar = utf16.withUnsafeBufferPointer { ptr -> String? in
            guard let base = ptr.baseAddress else { return nil }
            return String(utf16CodeUnits: base, count: length)
        }
        return scalar?.first
    }
}
