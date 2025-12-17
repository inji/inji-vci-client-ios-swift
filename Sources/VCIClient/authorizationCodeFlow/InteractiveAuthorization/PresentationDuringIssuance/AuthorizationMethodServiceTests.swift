import XCTest
@testable import VCIClient

private struct DummyRequestData: AuthorizationRequestData {}

private final class DummyAuthorizationMethodService: AuthorizationMethodService {
    func type() -> String {
        "dummy_type"
    }

    func authorizeUser(requestData: AuthorizationRequestData) async throws -> AuthorizationResponse {
        return AuthorizationResponse(
            authorizationCode: "dummy-code",
            status: "success",
            error: nil,
            errorDescription: nil,
            authSession: "dummy-session"
        )
    }
}

final class AuthorizationMethodServiceTests: XCTestCase {

    func test_type_and_authorizeUser_on_dummy_conformer() async throws {
        let service = DummyAuthorizationMethodService()
        XCTAssertEqual(service.type(), "dummy_type")

        let response = try await service.authorizeUser(requestData: DummyRequestData())
        XCTAssertEqual(response.status, "success")
        XCTAssertEqual(response.authorizationCode, "dummy-code")
        XCTAssertEqual(response.authSession, "dummy-session")
        XCTAssertNil(response.error)
        XCTAssertNil(response.errorDescription)
    }
}

