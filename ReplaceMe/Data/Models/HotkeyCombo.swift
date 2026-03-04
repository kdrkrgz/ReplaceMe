// HotkeyCombo.swift — Global activation keyboard shortcut value type

import AppKit
import Carbon

/// Immutable value type representing a keyboard shortcut (modifier flags + virtual key code).
/// Codable for UserDefaults JSON persistence; Hashable for use as dictionary key.
struct HotkeyCombo: Codable, Hashable, Equatable {

    /// Virtual key code — layout-independent (CGKeyCode raw value).
    let keyCode: UInt16

    /// Relevant modifier bits stored as UInt (Codable-friendly).
    /// Only .command, .option, .shift, .control are preserved.
    let modifiers: UInt

    // MARK: - Init

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode   = keyCode
        self.modifiers = modifiers
            .intersection([.control, .option, .shift, .command])
            .rawValue
    }

    // MARK: - Computed

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }

    /// Human-readable representation, e.g. "⌃⌥⇧⌘R".
    var displayString: String { modifierSymbols + keyName }

    var modifierSymbols: String {
        let f = modifierFlags
        var s = ""
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option)  { s += "⌥" }
        if f.contains(.shift)   { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        return s
    }

    var keyName: String { HotkeyCombo.keyName(for: keyCode) }

    // MARK: - Key Name Lookup

    static func keyName(for keyCode: UInt16) -> String {
        if let special = specialKeyNames[Int(keyCode)] { return special }
        return translateKeyCode(keyCode) ?? "(\(keyCode))"
    }

    /// Translates a virtual key code to its display label using the current keyboard layout.
    /// Falls back to the static table when TIS APIs are unavailable.
    private static func translateKeyCode(_ keyCode: UInt16) -> String? {
        guard
            let srcRef  = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let rawData = TISGetInputSourceProperty(srcRef, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = Unmanaged<CFData>.fromOpaque(rawData).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(layoutData) else { return nil }

        var result: String? = nil
        bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
            var deadKeyState: UInt32 = 0
            var actualLength = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let err = UCKeyTranslate(
                layout, keyCode, UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, 4, &actualLength, &chars
            )
            guard err == noErr, actualLength > 0 else { return }
            let s = String(utf16CodeUnits: Array(chars.prefix(actualLength)),
                           count: actualLength).uppercased()
            result = s.isEmpty ? nil : s
        }
        return result
    }

    private static let specialKeyNames: [Int: String] = [
        36: "↩",     // Return
        48: "⇥",     // Tab
        49: "Space",
        51: "⌫",     // Delete (backspace)
        52: "↩",     // Enter (numpad)
        53: "⎋",     // Escape
        71: "Clear",
        76: "↩",     // Enter
        115: "↖",    // Home
        116: "⇞",    // Page Up
        117: "⌦",    // Forward Delete
        119: "↘",    // End
        121: "⇟",    // Page Down
        122: "F1",  120: "F2",  99: "F3",  118: "F4",
         96: "F5",   97: "F6",  98: "F7",  100: "F8",
        101: "F9",  109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16",
         64: "F17",  79: "F18",  80: "F19",  90: "F20",
    ]
}
