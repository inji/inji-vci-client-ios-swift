@testable import VCIClient
import XCTest

final class DPoPAlgorithmTests: XCTestCase {
    func test_defaultsToEs256WhenNilOrEmpty() {
        XCTAssertEqual(DPoPAlgorithm.select(nil), .es256)
        XCTAssertEqual(DPoPAlgorithm.select([]), .es256)
    }

    func test_prefersEs256WhenMultipleAdvertised() {
        XCTAssertEqual(DPoPAlgorithm.select(["ES512", "ES384", "ES256"]), .es256)
    }

    func test_selectsOnlySupportedAdvertised() {
        XCTAssertEqual(DPoPAlgorithm.select(["RS256", "ES384"]), .es384)
    }

    func test_fallsBackToEs256WhenUnsupportedOnly() {
        XCTAssertEqual(DPoPAlgorithm.select(["RS256", "PS256"]), .es256)
    }
}
