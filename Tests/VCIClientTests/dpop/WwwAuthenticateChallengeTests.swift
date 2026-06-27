@testable import VCIClient
import XCTest

final class WwwAuthenticateChallengeTests: XCTestCase {
    func test_parsesDpopUseDpopNonceChallenge() {
        let challenge = WwwAuthenticateChallenge.parse(#"DPoP error="use_dpop_nonce", error_description="nonce required""#)
        XCTAssertTrue(challenge.isDpop)
        XCTAssertEqual(challenge.error, "use_dpop_nonce")
    }

    func test_parsesBearerOnlyChallenge() {
        let challenge = WwwAuthenticateChallenge.parse(#"Bearer realm="issuer", error="invalid_token""#)
        XCTAssertFalse(challenge.isDpop)
        XCTAssertEqual(challenge.error, "invalid_token")
    }

    func test_detectsDpopAmongMultipleSchemes() {
        let challenge = WwwAuthenticateChallenge.parse(#"Bearer realm="r", DPoP algs="ES256""#)
        XCTAssertTrue(challenge.isDpop)
    }

    func test_emptyForNilOrBlank() {
        for value in [nil, "", "   "] {
            let challenge = WwwAuthenticateChallenge.parse(value)
            XCTAssertFalse(challenge.isDpop)
            XCTAssertNil(challenge.error)
        }
    }
}
