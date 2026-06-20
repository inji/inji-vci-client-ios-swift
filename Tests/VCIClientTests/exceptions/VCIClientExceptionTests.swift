import XCTest
@testable import VCIClient

final class VCIClientExceptionTests: XCTestCase {

    func testCodeRetainsRootCodeFromNestedException() {
        let root = AuthorizationServerDiscoveryException("resolver failure")
        let wrapped = NetworkRequestFailedException(
            message: "token endpoint failed",
            issuerErrorCode: "server_error",
            issuerErrorDescription: "temporary issue",
            cause: root
        )

        XCTAssertEqual("VCI-001", wrapped.code)
        XCTAssertEqual("server_error", wrapped.issuerErrorCode)
        XCTAssertEqual("temporary issue", wrapped.issuerErrorDescription)
    }

    func testCodeResolvesToDeepestRootCodeAcrossMultiLevelChain() {
        let root = InvalidDataProvidedException("missing field")
        let mid = AuthorizationServerDiscoveryException(
            message: "discovery failed",
            cause: root
        )
        let outer = NetworkRequestFailedException(
            message: "token endpoint failed",
            cause: mid
        )

        XCTAssertEqual("VCI-004", outer.code)
    }

    func testCodeFallsBackToOwnCodeWhenNoVciCause() {
        let exception = NetworkRequestFailedException("connection reset")

        XCTAssertEqual("VCI-006", exception.code)
        XCTAssertNil(exception.issuerErrorCode)
        XCTAssertNil(exception.issuerErrorDescription)
    }
}
