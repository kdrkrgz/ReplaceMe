// SystemShortcutChecker.swift — Detects conflicts with macOS system keyboard shortcuts

import AppKit

/// Pure namespace — stateless, all methods are static, safe to call from any thread.
enum SystemShortcutChecker {

    // MARK: - Public API

    /// Returns a human-readable conflict description if `combo` clashes with a system shortcut,
    /// or `nil` when the combo is safe to use.
    static func conflictDescription(for combo: HotkeyCombo) -> String? {
        if let name = hardcodedConflicts[combo] {
            return name
        }
        if let name = symbolicHotkeyConflict(for: combo) {
            return name
        }
        return nil
    }

    // MARK: - Hardcoded System Shortcuts

    // Virtual key codes (US layout, layout-independent for modifier + letter combos)
    private static let hardcodedConflicts: [HotkeyCombo: String] = {
        typealias C = NSEvent.ModifierFlags
        func k(_ keyCode: UInt16, _ mods: C) -> HotkeyCombo { .init(keyCode: keyCode, modifiers: mods) }

        let cmd: C = .command
        let ctrl: C = .control
        let opt: C = .option
        let shift: C = .shift

        return [
            // Spotlight
            k(49, cmd):         "Spotlight Search (⌘Space)",
            k(49, ctrl):        "Input Method Switch (⌃Space)",
            k(49, [ctrl, opt]): "Spotlight Search (⌃⌥Space)",

            // App management
            k(48,  cmd):        "Application Switcher (⌘Tab)",
            k(50,  cmd):        "Window Cycle (⌘`)",
            k(4,   cmd):        "Hide Application (⌘H)",
            k(4,   [cmd, opt]): "Hide Others (⌘⌥H)",
            k(46,  cmd):        "Minimize Window (⌘M)",
            k(12,  cmd):        "Quit Application (⌘Q)",
            k(13,  cmd):        "Close Window (⌘W)",

            // Screenshots (Cmd+Shift+3/4/5)
            k(20, [cmd, shift]): "Screenshot (⌘⇧3)",
            k(21, [cmd, shift]): "Screenshot Selection (⌘⇧4)",
            k(23, [cmd, shift]): "Screenshot Options (⌘⇧5)",

            // Ctrl+Cmd+Q — Lock screen
            k(12, [ctrl, cmd]): "Lock Screen (⌃⌘Q)",

            // Mission Control
            k(126, ctrl): "Mission Control (⌃↑)",
            k(125, ctrl): "App Windows (⌃↓)",

            // Force Quit
            k(53, [cmd, opt]): "Force Quit Dialog (⌘⌥⎋)",
        ]
    }()

    // MARK: - Symbolic Hotkeys (~/Library/Preferences/com.apple.symbolichotkeys.plist)

    /// Parses the user's system keyboard shortcut preferences and checks for a conflict.
    private static func symbolicHotkeyConflict(for combo: HotkeyCombo) -> String? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")

        guard
            let dict = NSDictionary(contentsOf: url) as? [String: Any],
            let hotkeys = dict["AppleSymbolicHotKeys"] as? [String: Any]
        else { return nil }

        for (idStr, value) in hotkeys {
            guard
                let entry = value as? [String: Any],
                let enabled = entry["enabled"] as? Bool, enabled,
                let valueDict = entry["value"] as? [String: Any],
                let parameters = valueDict["parameters"] as? [Any],
                parameters.count >= 3,
                let keyCode = parameters[1] as? Int,
                let appleModifiers = parameters[2] as? Int,
                keyCode != 65535  // 65535 = unset
            else { continue }

            let flags = appleModifiersToNSFlags(appleModifiers)
            let entryCombo = HotkeyCombo(keyCode: UInt16(keyCode), modifiers: flags)
            if entryCombo == combo {
                return "System shortcut (ID \(idStr))"
            }
        }
        return nil
    }

    /// Apple's symbolichotkeys plist uses the same bit layout as CGEventFlags / NSEvent.ModifierFlags.
    /// kCGEventFlagMaskCommand  = 0x100000 = NSEvent.ModifierFlags.command.rawValue
    /// kCGEventFlagMaskAlternate= 0x080000 = NSEvent.ModifierFlags.option.rawValue
    /// kCGEventFlagMaskShift    = 0x020000 = NSEvent.ModifierFlags.shift.rawValue
    /// kCGEventFlagMaskControl  = 0x040000 = NSEvent.ModifierFlags.control.rawValue
    private static func appleModifiersToNSFlags(_ apple: Int) -> NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if apple & 0x100000 != 0 { f.insert(.command) }
        if apple & 0x080000 != 0 { f.insert(.option) }
        if apple & 0x020000 != 0 { f.insert(.shift) }
        if apple & 0x040000 != 0 { f.insert(.control) }
        return f
    }
}
