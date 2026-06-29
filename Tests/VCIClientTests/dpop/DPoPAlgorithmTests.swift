@testable import VCIClient
import XCTest

final class DPoPAlgorithmTests: XCTestCase {
    func test_defaultsToEs256WhenNilOrEmpty() {
        XCTAssertEqual(DPoPAlgorithm.select(nil), .es256)
        XCTAssertEqual(DPoPAlgorithm.select([]), .es256)
    }

    // Priority group 1 – ed (EdDSA)
    func test_prefersEdDSAOverAllOtherAlgorithms() {
        XCTAssertEqual(DPoPAlgorithm.select(["RS256", "ES256", "ES256K", "EdDSA"]), .eddsa)
    }

    // Priority group 2 – eck1 (ES256K / secp256k1)
    func test_prefersEs256kOverEcr1VariantsAndRsa() {
        XCTAssertEqual(DPoPAlgorithm.select(["ES512", "ES256K", "ES256"]), .es256k)
    }

    // Priority group 3 – ecr1 (ES256 / secp256r1)
    func test_prefersEs256OverLargerEcCurvesAndRsa() {
        XCTAssertEqual(DPoPAlgorithm.select(["ES512", "ES384", "ES256"]), .es256)
    }

    // Priority group 4 – other EC r1 variants (ES384 before ES512)
    func test_prefersEs384OverEs512AndRsa() {
        XCTAssertEqual(DPoPAlgorithm.select(["RS256", "ES512", "ES384"]), .es384)
    }

    func test_prefersEs512OverRsa() {
        XCTAssertEqual(DPoPAlgorithm.select(["RS256", "ES512"]), .es512)
    }

    // Priority group 5 – rsa (RS256); last resort
    func test_selectsRs256WhenOnlyRecognisedAlgorithm() {
        XCTAssertEqual(DPoPAlgorithm.select(["RS256", "PS512"]), .rs256)
    }

    func test_fallsBackToEs256WhenOnlyUnsupportedAdvertised() {
        XCTAssertEqual(DPoPAlgorithm.select(["PS256", "HS256"]), .es256)
    }
}
