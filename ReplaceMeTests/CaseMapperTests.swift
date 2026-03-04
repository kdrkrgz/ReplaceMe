import XCTest
@testable import ReplaceMe

final class CaseMapperTests: XCTestCase {

    // MARK: - CasePattern detection

    func testDetect_allLowercase() {
        XCTAssertEqual(CaseMapper.detect("sukur"), .allLowercase)
    }

    func testDetect_allUppercase() {
        XCTAssertEqual(CaseMapper.detect("SUKUR"), .allUppercase)
    }

    func testDetect_titleCase() {
        XCTAssertEqual(CaseMapper.detect("Sukur"), .titleCase)
    }

    func testDetect_mixed() {
        XCTAssertEqual(CaseMapper.detect("SuKuR"), .mixed)
    }

    func testDetect_singleLower() {
        XCTAssertEqual(CaseMapper.detect("s"), .allLowercase)
    }

    func testDetect_singleUpper() {
        XCTAssertEqual(CaseMapper.detect("S"), .allUppercase)
    }

    func testDetect_emptyString() {
        // Empty string → no pattern, falls through to allLowercase
        XCTAssertEqual(CaseMapper.detect(""), .allLowercase)
    }

    // MARK: - applyCase

    func testApplyCase_lowercase_to_lowercase_replacement() {
        let result = CaseMapper.applyCase(of: "sukur", to: "şükür")
        XCTAssertEqual(result, "şükür")
    }

    func testApplyCase_titleCase_to_replacement() {
        let result = CaseMapper.applyCase(of: "Sukur", to: "şükür")
        XCTAssertEqual(result, "Şükür")
    }

    func testApplyCase_allUppercase_to_replacement() {
        let result = CaseMapper.applyCase(of: "SUKUR", to: "şükür")
        XCTAssertEqual(result, "ŞÜKÜR")
    }

    func testApplyCase_mixed_to_replacement() {
        // Mixed → title case applied to replacement
        let result = CaseMapper.applyCase(of: "SuKuR", to: "şükür")
        XCTAssertEqual(result, "Şükür")
    }

    func testApplyCase_singleLetter_lower() {
        let result = CaseMapper.applyCase(of: "s", to: "ş")
        XCTAssertEqual(result, "ş")
    }

    func testApplyCase_singleLetter_upper() {
        let result = CaseMapper.applyCase(of: "S", to: "ş")
        XCTAssertEqual(result, "Ş")
    }

    func testApplyCase_turkish_title() {
        let result = CaseMapper.applyCase(of: "Gozum", to: "gözüm")
        XCTAssertEqual(result, "Gözüm")
    }

    func testApplyCase_turkish_upper() {
        let result = CaseMapper.applyCase(of: "GOZUM", to: "gözüm")
        XCTAssertEqual(result, "GÖZÜM")
    }
}
