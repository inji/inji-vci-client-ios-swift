import XCTest
@testable import VCIClient

final class InteractiveAuthorizationResponseTests: XCTestCase {

    func testInit_success_whenStatusRequireInteraction_withTypeAndAuthSession() throws {
        let sut = try InteractiveAuthorizationResponse(
            status: "require_interaction",
            type: "some_type",
            authSession: "session123"
        )
        XCTAssertEqual(sut.status, "require_interaction")
        XCTAssertEqual(sut.type, "some_type")
        XCTAssertEqual(sut.authSession, "session123")
    }

    func testInit_success_whenStatusIsOther_allowsMissingTypeAndAuthSession() throws {
        let sut = try InteractiveAuthorizationResponse(
            status: "done",
            type: nil,
            authSession: nil
        )
        XCTAssertEqual(sut.status, "done")
        XCTAssertNil(sut.type)
        XCTAssertNil(sut.authSession)
    }

    func testInit_throws_whenStatusMissing() {
        XCTAssertThrowsError(try InteractiveAuthorizationResponse(
            status: nil,
            type: "x",
            authSession: "y"
        )) { error in
            guard let e = error as? IllegalArgumentException else {
                return XCTFail("Expected IllegalArgumentException, got \(type(of: error))")
            }
            XCTAssertTrue(e.message.contains("Missing or empty 'status'"))
        }
    }

    func testInit_throws_whenStatusBlank() {
        XCTAssertThrowsError(try InteractiveAuthorizationResponse(
            status: "   ",
            type: "x",
            authSession: "y"
        )) { error in
            guard let e = error as? IllegalArgumentException else {
                return XCTFail("Expected IllegalArgumentException, got \(type(of: error))")
            }
            XCTAssertTrue(e.message.contains("Missing or empty 'status'"))
        }
    }

    func testInit_throws_whenRequireInteraction_butTypeMissing() {
        XCTAssertThrowsError(try InteractiveAuthorizationResponse(
            status: "require_interaction",
            type: nil,
            authSession: "session"
        )) { error in
            guard let e = error as? IllegalArgumentException else {
                return XCTFail("Expected IllegalArgumentException, got \(type(of: error))")
            }
            XCTAssertTrue(e.message.contains("'type' is required"))
        }
    }

    func testInit_throws_whenRequireInteraction_butTypeBlank() {
        XCTAssertThrowsError(try InteractiveAuthorizationResponse(
            status: "require_interaction",
            type: "",
            authSession: "session"
        )) { error in
            guard let e = error as? IllegalArgumentException else {
                return XCTFail("Expected IllegalArgumentException, got \(type(of: error))")
            }
            XCTAssertTrue(e.message.contains("'type' is required"))
        }
    }

    func testInit_throws_whenRequireInteraction_butAuthSessionMissing() {
        XCTAssertThrowsError(try InteractiveAuthorizationResponse(
            status: "require_interaction",
            type: "some_type",
            authSession: nil
        )) { error in
            guard let e = error as? IllegalArgumentException else {
                return XCTFail("Expected IllegalArgumentException, got \(type(of: error))")
            }
            XCTAssertTrue(e.message.contains("'authSession' is required"))
        }
    }

    func testInit_throws_whenRequireInteraction_butAuthSessionBlank() {
        XCTAssertThrowsError(try InteractiveAuthorizationResponse(
            status: "require_interaction",
            type: "some_type",
            authSession: ""
        )) { error in
            guard let e = error as? IllegalArgumentException else {
                return XCTFail("Expected IllegalArgumentException, got \(type(of: error))")
            }
            XCTAssertTrue(e.message.contains("'authSession' is required"))
        }
    }
}

