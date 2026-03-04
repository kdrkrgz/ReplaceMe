// SystemShortcutCheckerTests.swift — Unit tests for SystemShortcutChecker

import XCTest
@testable import ReplaceMe

final class SystemShortcutCheckerTests: XCTestCase {

    // MARK: - Known hardcoded conflicts

    func testSpotlightCmdSpaceConflicts() {
        let combo = HotkeyCombo(keyCode: 49, modifiers: .command)
        XCTAssertNotNil(SystemShortcutChecker.conflictDescription(for: combo), "⌘Space should conflict with Spotlight")
    }

    func testAppSwitcherCmdTabConflicts() {
        let combo = HotkeyCombo(keyCode: 48, modifiers: .command)
        XCTAssertNotNil(SystemShortcutChecker.conflictDescription(for: combo), "⌘Tab should conflict with App Switcher")
    }

    func testQuitCmdQConflicts() {
        let combo = HotkeyCombo(keyCode: 12, modifiers: .command)
        XCTAssertNotNil(SystemShortcutChecker.conflictDescription(for: combo), "⌘Q should conflict with Quit")
    }

    func testScreenshotCmdShift3Conflicts() {
        let combo = HotkeyCombo(keyCode: 20, modifiers: [.command, .shift])
        XCTAssertNotNil(SystemShortcutChecker.conflictDescription(for: combo), "⌘⇧3 should conflict with Screenshot")
    }

    func testScreenshotCmdShift4Conflicts() {
        let combo = HotkeyCombo(keyCode: 21, modifiers: [.command, .shift])
        XCTAssertNotNil(SystemShortcutChecker.conflictDescription(for: combo))
    }

    func testScreenshotCmdShift5Conflicts() {
        let combo = HotkeyCombo(keyCode: 23, modifiers: [.command, .shift])
        XCTAssertNotNil(SystemShortcutChecker.conflictDescription(for: combo))
    }

    func testForceQuitCmdOptEscConflicts() {
        let combo = HotkeyCombo(keyCode: 53, modifiers: [.command, .option])
        XCTAssertNotNil(SystemShortcutChecker.conflictDescription(for: combo), "⌘⌥⎋ should conflict with Force Quit")
    }

    // MARK: - Valid combos (no conflict expected for uncommon combos)

    func testUncommonComboHasNoHardcodedConflict() {
        // ⌃⌥⌘R — unlikely to be a system shortcut in hardcoded list
        let combo = HotkeyCombo(keyCode: 15, modifiers: [.control, .option, .command])
        // This may or may not conflict depending on user's system shortcuts.
        // We can only assert the function doesn't crash.
        _ = SystemShortcutChecker.conflictDescription(for: combo)
    }

    func testConflictDescriptionDoesNotCrash_withVariousKeyCodes() {
        // Smoke test: iterate typical key codes and ensure no crash
        let modifiers: NSEvent.ModifierFlags = .command
        for keyCode in UInt16(0)..<UInt16(128) {
            _ = SystemShortcutChecker.conflictDescription(for: HotkeyCombo(keyCode: keyCode, modifiers: modifiers))
        }
    }
}
