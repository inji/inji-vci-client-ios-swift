import XCTest
@testable import VCIClient

final class StringOptionalIsBlankTests: XCTestCase {

    func testNilIsBlank() {
        let str: String? = nil
        XCTAssertTrue(str.isBlank(), "nil should be blank")
    }

    func testEmptyStringIsBlank() {
        let str: String? = ""
        XCTAssertTrue(str.isBlank(), "Empty string should be blank")
    }

    func testSpacesOnlyIsBlank() {
        let str: String? = "    "
        XCTAssertTrue(str.isBlank(), "Spaces-only string should be blank")
    }

    func testNonBlankStringIsNotBlank() {
        let str: String? = "Hello"
        XCTAssertFalse(str.isBlank(), "Non-blank string should not be blank")
    }

    func testStringWithSpacesAndTextIsNotBlank() {
        let str: String? = "  Hello  "
        XCTAssertFalse(str.isBlank(), "String with spaces and text should not be blank")
    }
    
    func testNewlineIsNotBlank() {
        let str: String? = "\n"
        XCTAssertFalse(str.isBlank())
    }

    func testTabIsNotBlank() {
        let str: String? = "\t"
        XCTAssertFalse(str.isBlank())
    }

    func testFormURLEncodedEncodesSpace() {
        let input = "hello world"
        let encoded = input.formURLEncoded()

        XCTAssertTrue(encoded.contains("%20"))
    }

    func testFormURLEncodedEncodesSpecialCharacters() {
        let input = "a+b&c=d"
        let encoded = input.formURLEncoded()

        XCTAssertTrue(encoded.contains("%2B"))
        XCTAssertTrue(encoded.contains("%26"))
        XCTAssertTrue(encoded.contains("%3D"))
    }

    func testFormURLEncodedLeavesSafeCharactersUnchanged() {
        let input = "hello123"
        let encoded = input.formURLEncoded()

        XCTAssertEqual(encoded, "hello123")
    }

    func testFormURLEncodedHandlesUnicodeCharacters() {
        let input = "こんにちは"
        let encoded = input.formURLEncoded()

        XCTAssertNotEqual(encoded, input)
    }
}
