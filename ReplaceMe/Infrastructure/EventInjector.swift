// EventInjector.swift — Sentetik klavye event'i üretimi

import CoreGraphics
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "EventInjector")

/// Inject edilen tüm event'lere eklenen tag — sonsuz döngü koruması.
/// "RM_RM" ASCII: 0x524D5F524D
let RM_EVENT_TAG: Int64 = 0x524D5F524D

final class EventInjector {

    static let shared = EventInjector()

    private let source: CGEventSource?

    private init() {
        source = CGEventSource(stateID: .hidSystemState)
        // Inject süresince mouse event'lerini geçir, keyboard'u suppress et
        source?.setLocalEventsFilterDuringSuppressionState(
            .permitLocalMouseEvents,
            state: .eventSuppressionStateSuppressionInterval
        )
    }

    /// N adet backspace event'i gönder (keyDown + keyUp çifti).
    func sendBackspaces(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            postKey(virtualKey: 51, keyDown: true)   // Delete key down
            postKey(virtualKey: 51, keyDown: false)  // Delete key up
        }
        log.debug("Injected \(count) backspace(s)")
    }

    /// Unicode string'i klavye event'i olarak gönder (virtual key bağımsız).
    func inject(string: String) {
        guard !string.isEmpty else { return }
        let utf16 = Array(string.utf16)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        keyDown?.setIntegerValueField(.eventSourceUserData, value: RM_EVENT_TAG)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        keyUp?.setIntegerValueField(.eventSourceUserData, value: RM_EVENT_TAG)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        log.debug("Injected string: \(string)")
    }

    // MARK: - Private

    private func postKey(virtualKey: CGKeyCode, keyDown: Bool) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: keyDown)
        event?.setIntegerValueField(.eventSourceUserData, value: RM_EVENT_TAG)
        event?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
