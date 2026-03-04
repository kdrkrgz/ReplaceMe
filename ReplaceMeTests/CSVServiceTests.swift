import XCTest
@testable import ReplaceMe

final class CSVServiceTests: XCTestCase {

    // MARK: - Parse

    func testParse_basicTwoColumn() {
        let csv = "sukur,şükür\ngozum,gözüm\n"
        let rules = CSVService.parse(csv)
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules["sukur"], "şükür")
        XCTAssertEqual(rules["gozum"], "gözüm")
    }

    func testParse_skipsEmptyLines() {
        let csv = "a,b\n\nc,d\n"
        let rules = CSVService.parse(csv)
        XCTAssertEqual(rules.count, 2)
    }

    func testParse_skipsInvalidLines() {
        let csv = "valid,line\ninvalidline\n"
        let rules = CSVService.parse(csv)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules["valid"], "line")
    }

    func testParse_emptyCSV_returnsEmpty() {
        let rules = CSVService.parse("")
        XCTAssertTrue(rules.isEmpty)
    }

    // MARK: - Serialize

    func testSerialize_producesCorrectFormat() {
        let rules = ["a": "b"]
        let csv = CSVService.serialize(rules)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertTrue(lines.contains("a,b"))
    }

    func testSerialize_roundtrip() {
        let original = ["sukur": "şükür", "gozum": "gözüm"]
        let csv = CSVService.serialize(original)
        let parsed = CSVService.parse(csv)
        XCTAssertEqual(parsed, original)
    }

    func testSerialize_emptyRules_returnsEmpty() {
        let csv = CSVService.serialize([:])
        XCTAssertTrue(csv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

