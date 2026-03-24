@testable import VCIClient
import XCTest

final class PresentationInteractionResponseTests: XCTestCase {
    func testInitFromJson_requiresOpenId4VpRequest() {
        XCTAssertThrowsError(
            try PresentationInteractionResponse(
                json: [
                    "status": "require_interaction",
                    "type": "openid4vp_presentation",
                    "auth_session": "session-1",
                ]
            )
        ) { error in
            XCTAssertTrue(error is IllegalArgumentException)
        }
    }

    func testDecoding_acceptsNestedDictionaryRequest() throws {
        let data = """
        {
            "status": "require_interaction",
            "type": "openid4vp_presentation",
            "auth_session": "session-1",
            "openid4vp_request": {
                "response_type": "vp_token",
                "response_mode": "iar-post",
                "presentation_definition": {
                    "id": "pd-1"
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(
            PresentationInteractionResponse.self,
            from: data
        )

        XCTAssertEqual(response.status, "require_interaction")
        XCTAssertEqual(response.authSession, "session-1")
        XCTAssertEqual(response.openid4vpRequest["response_type"] as? String, "vp_token")
        XCTAssertEqual(
            (response.openid4vpRequest["presentation_definition"] as? [String: Any])?["id"] as? String,
            "pd-1"
        )
    }

    func testValidate_acceptsUnsignedRequestWithSupportedResponseMode() throws {
        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "openid4vp_presentation",
                "auth_session": "session-1",
                "openid4vp_request": [
                    "response_type": "vp_token",
                    "response_mode": "iar-post.jwt",
                ],
            ]
        )

        XCTAssertNoThrow(try response.validate())
    }

    func testValidate_acceptsSignedRequestWithSupportedResponseMode() throws {
        let payload = #"{"response_mode":"iar-post"}"#
        let encodedPayload = Data(payload.utf8).base64URLEncodedString()
        let jwt = "header.\(encodedPayload).signature"

        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "openid4vp_presentation",
                "auth_session": "session-1",
                "openid4vp_request": [
                    "request": jwt,
                ],
            ]
        )

        XCTAssertNoThrow(try response.validate())
    }

    func testValidate_rejectsInvalidType() throws {
        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "wrong_type",
                "auth_session": "session-1",
                "openid4vp_request": [
                    "response_type": "vp_token",
                    "response_mode": "iar-post",
                ],
            ]
        )

        XCTAssertThrowsError(try response.validate()) { error in
            XCTAssertTrue(error is IllegalArgumentException)
        }
    }

    func testValidate_rejectsMissingResponseTypeInUnsignedRequest() throws {
        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "openid4vp_presentation",
                "auth_session": "session-1",
                "openid4vp_request": [
                    "response_mode": "iar-post",
                ],
            ]
        )

        XCTAssertThrowsError(try response.validate())
    }

    func testValidate_rejectsInvalidResponseTypeInUnsignedRequest() throws {
        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "openid4vp_presentation",
                "auth_session": "session-1",
                "openid4vp_request": [
                    "response_type": "code",
                    "response_mode": "iar-post",
                ],
            ]
        )

        XCTAssertThrowsError(try response.validate())
    }

    func testValidate_rejectsMissingResponseMode() throws {
        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "openid4vp_presentation",
                "auth_session": "session-1",
                "openid4vp_request": [
                    "response_type": "vp_token",
                ],
            ]
        )

        XCTAssertThrowsError(try response.validate()) { error in
            XCTAssertTrue(error is IllegalArgumentException)
        }
    }

    func testValidate_rejectsUnsupportedResponseMode() throws {
        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "openid4vp_presentation",
                "auth_session": "session-1",
                "openid4vp_request": [
                    "response_type": "vp_token",
                    "response_mode": "direct_post",
                ],
            ]
        )

        XCTAssertThrowsError(try response.validate()) { error in
            XCTAssertTrue(error is IllegalArgumentException)
        }
    }

    func testValidate_rejectsMalformedSignedRequestJwt() throws {
        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "openid4vp_presentation",
                "auth_session": "session-1",
                "openid4vp_request": [
                    "request": "not-a-jwt",
                ],
            ]
        )

        XCTAssertThrowsError(try response.validate())
    }

    func testDecodeJwtPayload_rejectsNonDictionaryPayload() throws {
        let payload = #"["not","a","dictionary"]"#
        let encodedPayload = Data(payload.utf8).base64URLEncodedString()
        let jwt = "header.\(encodedPayload).signature"
        let response = try PresentationInteractionResponse(
            json: [
                "status": "require_interaction",
                "type": "openid4vp_presentation",
                "auth_session": "session-1",
                "openid4vp_request": [:],
            ]
        )

        XCTAssertThrowsError(try response.decodeJwtPayload(jwt: jwt))
    }
}
