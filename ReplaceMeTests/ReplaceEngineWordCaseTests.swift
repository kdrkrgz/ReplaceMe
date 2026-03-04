// ReplaceEngineWordCaseTests.swift — Word replace + Capital/Uppercase sub-option tests
//
// State matrix under test:
//   CI=OFF, Cap=OFF, Upper=OFF → exact lowercase match only
//   CI=OFF, Cap=ON,  Upper=OFF → lowercase + titleCase match; allUppercase NOT matched
//   CI=OFF, Cap=OFF, Upper=ON  → lowercase + allUppercase match; titleCase NOT matched
//   CI=ON,  Cap=ON,  Upper=ON  → all case forms matched with appropriate transform

import XCTest
@testable import ReplaceMe

/// Space keyCode = 49 — used as word terminator in tests.
private let spaceKeyCode: Int64 = 49

final class ReplaceEngineWordCaseTests: XCTestCase {

    // MARK: - Helpers

    /// Type all characters of `word` then a space to flush the buffer.
    /// Returns the ReplaceAction produced by the terminating space.
    @discardableResult
    private func typeWord(_ word: String, engine: ReplaceEngine) async -> ReplaceAction {
        var lastAction: ReplaceAction = .passthrough
        for ch in word {
            lastAction = await engine.process(character: ch, keyCode: 0)
        }
        lastAction = await engine.process(character: " ", keyCode: spaceKeyCode)
        return lastAction
    }

    private func makeEngine(wordRules: [String: String],
                            wordCI: Bool,
                            wordCap: Bool,
                            wordUpper: Bool) async -> ReplaceEngine {
        let dict = DictionaryStore()
        await dict.replaceAllWordRules(wordRules)

        // Drive SettingsStore.shared to configure the cached bools.
        // Using main-actor setter guarantees didSet fires and updates *Cached vars.
        await MainActor.run {
            SettingsStore.shared.isWordReplaceActive    = true
            SettingsStore.shared.isLetterReplaceActive  = false
            SettingsStore.shared.isWordCaseInsensitive  = wordCI
            SettingsStore.shared.isWordCapitalReplace   = wordCap
            SettingsStore.shared.isWordUppercaseReplace = wordUpper
        }

        return ReplaceEngine(dictionary: dict, settings: SettingsStore.shared)
    }

    // MARK: - CI=OFF, Cap=OFF, Upper=OFF (exact match only)

    func testExactOnly_lowercase_matches() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: false, wordUpper: false)
        let action = await typeWord("yuz", engine: engine)
        if case .replaceWord(_, let insert, _) = action {
            XCTAssertEqual(insert, "yüz")
        } else {
            XCTFail("Expected replaceWord, got \(action)")
        }
    }

    func testExactOnly_titleCase_notMatched() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: false, wordUpper: false)
        let action = await typeWord("Yuz", engine: engine)
        // "Yuz" has no exact key → passthrough
        XCTAssertEqual(action, .passthrough)
    }

    func testExactOnly_uppercase_notMatched() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: false, wordUpper: false)
        let action = await typeWord("YUZ", engine: engine)
        XCTAssertEqual(action, .passthrough)
    }

    // MARK: - CI=OFF, Cap=ON, Upper=OFF

    func testCapitalOnly_lowercase_matches() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: true, wordUpper: false)
        let action = await typeWord("yuz", engine: engine)
        if case .replaceWord(_, let insert, _) = action {
            XCTAssertEqual(insert, "yüz")
        } else { XCTFail("Expected replaceWord") }
    }

    func testCapitalOnly_titleCase_matchesWithTransform() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: true, wordUpper: false)
        let action = await typeWord("Yuz", engine: engine)
        if case .replaceWord(_, let insert, _) = action {
            XCTAssertEqual(insert, "Yüz")
        } else { XCTFail("Expected replaceWord with titleCase transform") }
    }

    func testCapitalOnly_uppercase_notMatched() async {
        // Uppercase=OFF → allUppercase input must NOT be replaced
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: true, wordUpper: false)
        let action = await typeWord("YUZ", engine: engine)
        XCTAssertEqual(action, .passthrough)
    }

    // MARK: - CI=OFF, Cap=OFF, Upper=ON

    func testUppercaseOnly_lowercase_matches() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: false, wordUpper: true)
        let action = await typeWord("yuz", engine: engine)
        if case .replaceWord(_, let insert, _) = action {
            XCTAssertEqual(insert, "yüz")
        } else { XCTFail("Expected replaceWord") }
    }

    func testUppercaseOnly_allUppercase_matchesWithTransform() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: false, wordUpper: true)
        let action = await typeWord("YUZ", engine: engine)
        if case .replaceWord(_, let insert, _) = action {
            XCTAssertEqual(insert, "YÜZ")
        } else { XCTFail("Expected replaceWord with uppercase transform") }
    }

    func testUppercaseOnly_titleCase_notMatched() async {
        // Capital=OFF → titleCase input must NOT be replaced
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: false, wordCap: false, wordUpper: true)
        let action = await typeWord("Yuz", engine: engine)
        XCTAssertEqual(action, .passthrough)
    }

    // MARK: - CI=ON, Cap=ON, Upper=ON (full case-insensitive replace)

    func testFullCI_lowercase_matches() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: true, wordCap: true, wordUpper: true)
        let action = await typeWord("yuz", engine: engine)
        if case .replaceWord(_, let insert, _) = action {
            XCTAssertEqual(insert, "yüz")
        } else { XCTFail("Expected replaceWord") }
    }

    func testFullCI_titleCase_matchesWithCapitalTransform() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: true, wordCap: true, wordUpper: true)
        let action = await typeWord("Yuz", engine: engine)
        if case .replaceWord(_, let insert, _) = action {
            XCTAssertEqual(insert, "Yüz")
        } else { XCTFail("Expected replaceWord with titleCase transform") }
    }

    func testFullCI_allUppercase_matchesWithUppercaseTransform() async {
        let engine = await makeEngine(wordRules: ["yuz": "yüz"],
                                      wordCI: true, wordCap: true, wordUpper: true)
        let action = await typeWord("YUZ", engine: engine)
        if case .replaceWord(_, let insert, _) = action {
            XCTAssertEqual(insert, "YÜZ")
        } else { XCTFail("Expected replaceWord with uppercase transform") }
    }

    // MARK: - Turkish dotless-i edge case (sukur/şükür)

    func testCapitalOnly_turkish_sukur() async {
        let engine = await makeEngine(wordRules: ["sukur": "şükür"],
                                      wordCI: false, wordCap: true, wordUpper: false)

        // "Sukur" → "Şükür"
        let titleAction = await typeWord("Sukur", engine: engine)
        if case .replaceWord(_, let insert, _) = titleAction {
            XCTAssertEqual(insert, "Şükür")
        } else { XCTFail("Expected titleCase transform") }

        // "sukur" → "şükür" (exact)
        let lowerAction = await typeWord("sukur", engine: engine)
        if case .replaceWord(_, let insert, _) = lowerAction {
            XCTAssertEqual(insert, "şükür")
        } else { XCTFail("Expected exact lowercase match") }
    }

    func testUppercaseOnly_turkish_sukur() async {
        let engine = await makeEngine(wordRules: ["sukur": "şükür"],
                                      wordCI: false, wordCap: false, wordUpper: true)

        // "SUKUR" → "ŞÜKÜR"
        let upperAction = await typeWord("SUKUR", engine: engine)
        if case .replaceWord(_, let insert, _) = upperAction {
            XCTAssertEqual(insert, "ŞÜKÜR")
        } else { XCTFail("Expected uppercase transform") }

        // "Sukur" should NOT be replaced (Capital=OFF)
        let titleAction = await typeWord("Sukur", engine: engine)
        XCTAssertEqual(titleAction, .passthrough)
    }
}
