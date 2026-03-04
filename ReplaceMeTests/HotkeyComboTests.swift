// HotkeyComboTests.swift — Unit tests for HotkeyCombo

import XCTest
@testable import ReplaceMe

final class HotkeyComboTests: XCTestCase {

    // MARK: - Modifier masking

    func testModifiersAreMaskedToRelevantBits() {
        let combo = HotkeyCombo(keyCode: 0, modifiers: [.command, .numericPad])
        XCTAssertEqual(combo.modifierFlags, .command, "numericPad should be stripped")
    }

    func testAllRelevantModifiersPreserved() {
        let all: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        let combo = HotkeyCombo(keyCode: 0, modifiers: all)
        XCTAssertEqual(combo.modifierFlags, all)
    }

    // MARK: - Display string

    func testModifierSymbolOrder() {
        // Expected order: ⌃⌥⇧⌘
        let combo = HotkeyCombo(keyCode: 15, modifiers: [.command, .option, .shift, .control])
        XCTAssertTrue(combo.modifierSymbols.hasPrefix("⌃⌥⇧⌘"), "modifier symbol order must be ⌃⌥⇧⌘, got: \(combo.modifierSymbols)")
    }

    func testDisplayStringContainsKeyName() {
        let combo = HotkeyCombo(keyCode: 49, modifiers: .option) // ⌥Space
        XCTAssertTrue(combo.displayString.contains("Space"), "expected Space in display string, got: \(combo.displayString)")
    }

    func testSpecialKeyNames() {
        XCTAssertEqual(HotkeyCombo.keyName(for: 36),  "↩")
        XCTAssertEqual(HotkeyCombo.keyName(for: 48),  "⇥")
        XCTAssertEqual(HotkeyCombo.keyName(for: 49),  "Space")
        XCTAssertEqual(HotkeyCombo.keyName(for: 51),  "⌫")
        XCTAssertEqual(HotkeyCombo.keyName(for: 53),  "⎋")
        XCTAssertEqual(HotkeyCombo.keyName(for: 122), "F1")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = HotkeyCombo(keyCode: 15, modifiers: [.command, .option])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyCombo.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testCodablePreservesKeyCode() throws {
        let original = HotkeyCombo(keyCode: 42, modifiers: .control)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyCombo.self, from: data)
        XCTAssertEqual(decoded.keyCode, 42)
    }

    // MARK: - Equality and hashing

    func testEqualCombosAreEqual() {
        let a = HotkeyCombo(keyCode: 15, modifiers: .command)
        let b = HotkeyCombo(keyCode: 15, modifiers: .command)
        XCTAssertEqual(a, b)
    }

    func testDifferentKeyCodeNotEqual() {
        let a = HotkeyCombo(keyCode: 15, modifiers: .command)
        let b = HotkeyCombo(keyCode: 16, modifiers: .command)
        XCTAssertNotEqual(a, b)
    }

    func testDifferentModifiersNotEqual() {
        let a = HotkeyCombo(keyCode: 15, modifiers: .command)
        let b = HotkeyCombo(keyCode: 15, modifiers: .option)
        XCTAssertNotEqual(a, b)
    }

    func testUsableAsDictionaryKey() {
        let combo = HotkeyCombo(keyCode: 15, modifiers: .command)
        var dict: [HotkeyCombo: String] = [:]
        dict[combo] = "found"
        XCTAssertEqual(dict[HotkeyCombo(keyCode: 15, modifiers: .command)], "found")
    }
}
