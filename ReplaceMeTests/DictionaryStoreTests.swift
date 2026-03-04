import XCTest
@testable import ReplaceMe

final class DictionaryStoreTests: XCTestCase {

    // MARK: - Snapshot CI maps (letter)

    func testSnapshot_ciLetterRules_lowercaseKey() async {
        let store = DictionaryStore()
        await store.setLetterRule(from: "S", to: "Ş")
        let snapshot = store.cachedSnapshot
        XCTAssertEqual(snapshot.letterRules["S"], "Ş")
        XCTAssertEqual(snapshot.ciLetterRules["s"], "Ş")
    }

    func testSnapshot_ciLetterRules_alreadyLowerKey_stillMapped() async {
        let store = DictionaryStore()
        await store.setLetterRule(from: "s", to: "ş")
        let snapshot = store.cachedSnapshot
        XCTAssertEqual(snapshot.ciLetterRules["s"], "ş")
    }

    // MARK: - Snapshot CI maps (word)

    func testSnapshot_ciWordRules_lowercaseKey() async {
        let store = DictionaryStore()
        await store.setWordRule(from: "Sukur", to: "şükür")
        let snapshot = store.cachedSnapshot
        XCTAssertEqual(snapshot.wordRules["Sukur"], "şükür")
        XCTAssertEqual(snapshot.ciWordRules["sukur"], "şükür")
    }

    func testSnapshot_multipleWordRules_allMapped() async {
        let store = DictionaryStore()
        await store.setWordRule(from: "sukur", to: "şükür")
        await store.setWordRule(from: "gozum", to: "gözüm")
        let snapshot = store.cachedSnapshot
        XCTAssertEqual(snapshot.ciWordRules.count, 2)
        XCTAssertEqual(snapshot.ciWordRules["sukur"], "şükür")
        XCTAssertEqual(snapshot.ciWordRules["gozum"], "gözüm")
    }

    func testRemoveWordRule_removesFromBothMaps() async {
        let store = DictionaryStore()
        await store.setWordRule(from: "sukur", to: "şükür")
        await store.removeWordRule(from: "sukur")
        let snapshot = store.cachedSnapshot
        XCTAssertNil(snapshot.wordRules["sukur"])
        XCTAssertNil(snapshot.ciWordRules["sukur"])
    }

    func testRemoveLetterRule_removesFromBothMaps() async {
        let store = DictionaryStore()
        await store.setLetterRule(from: "s", to: "ş")
        await store.removeLetterRule(from: "s")
        let snapshot = store.cachedSnapshot
        XCTAssertNil(snapshot.letterRules["s"])
        XCTAssertNil(snapshot.ciLetterRules["s"])
    }

    // MARK: - replaceAll

    func testReplaceAllWordRules_updatesSnapshot() async {
        let store = DictionaryStore()
        await store.replaceAllWordRules(["a": "b", "C": "D"])
        let snapshot = store.cachedSnapshot
        XCTAssertEqual(snapshot.ciWordRules["a"], "b")
        XCTAssertEqual(snapshot.ciWordRules["c"], "D")
    }
}

