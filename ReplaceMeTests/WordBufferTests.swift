import XCTest
@testable import ReplaceMe

final class WordBufferTests: XCTestCase {

    // MARK: - Append & current

    func testAppend_buildsString() {
        var buf = WordBuffer()
        buf.append("m")
        buf.append("e")
        buf.append("r")
        XCTAssertEqual(buf.current, "mer")
    }

    func testAppend_space_includesSpace() {
        var buf = WordBuffer()
        buf.append("a")
        buf.append("b")
        buf.append(" ")
        // WordBuffer does not reset on space — that's ReplaceEngine's responsibility
        XCTAssertEqual(buf.current, "ab ")
    }

    // MARK: - deleteLastCharacter

    func testDeleteLastCharacter_removesLast() {
        var buf = WordBuffer()
        buf.append("h")
        buf.append("i")
        buf.deleteLastCharacter()
        XCTAssertEqual(buf.current, "h")
    }

    func testDeleteLastCharacter_emptyBuffer_noError() {
        var buf = WordBuffer()
        buf.deleteLastCharacter() // Should not crash
        XCTAssertEqual(buf.current, "")
    }

    // MARK: - clear

    func testClear_resetsBuffer() {
        var buf = WordBuffer()
        buf.append("a")
        buf.append("b")
        buf.clear()
        XCTAssertEqual(buf.current, "")
    }

    // MARK: - flush

    func testFlush_returnsCurrentAndClears() {
        var buf = WordBuffer()
        buf.append("h")
        buf.append("i")
        let flushed = buf.flush()
        XCTAssertEqual(flushed, "hi")
        XCTAssertEqual(buf.current, "")
    }

    func testFlush_emptyReturnsEmpty() {
        var buf = WordBuffer()
        XCTAssertEqual(buf.flush(), "")
    }
}
