@testable import VCIClient
import XCTest

final class RedirectToWebAuthorizationMethodServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeValidRequestData(
        authorizeUrl: String = "https://auth.example.com/authorize",
        clientId: String = "client-123",
        redirectUri: String = "https://wallet.example.com/callback",
        scope: String = "openid profile",
        codeVerifier: String = "verifier-abc",
        codeChallenge: String = "challenge-xyz",
        state: String = "state-123",
        nonce: String = "nonce-456"
    ) -> ImplicitAuthorizationRequestData {
        let clientMetadata = ClientMetadata(clientId: clientId, redirectUri: redirectUri)
        let pkceSession = PKCESessionManager.PKCESession(
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge,
            state: state,
            nonce: nonce
        )
        return ImplicitAuthorizationRequestData(
            authorizeUrl: authorizeUrl,
            clientMetadata: clientMetadata,
            pkceSession: pkceSession,
            scope: scope,
            dpopJkt: "test-jkt"
        )
    }

    // MARK: - Tests

    func test_type_returnsRedirectToWeb() {
        let service = RedirectToWebAuthorizationMethodService { _ in [:] }
        XCTAssertEqual(service.type(), InteractionType.redirectToWeb.rawValue)
    }

    func test_authorizeUser_withInvalidRequestData_throwsIllegalArgument() async {
        let service = RedirectToWebAuthorizationMethodService { _ in [:] }
        let invalidRequest = DummyAuthorizationRequestData()

        do {
            _ = try await service.authorizeUser(requestData: invalidRequest)
            XCTFail("Expected IllegalArgumentException to be thrown")
        } catch is InteractiveAuthorizationException {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_authorizeUser_withErrorResponse_mapsToErrorAuthorizationResponse() async throws {
        let service = RedirectToWebAuthorizationMethodService { _ in
            [
                "error": "access_denied",
                "error_description": "User denied access"
            ]
        }
        let request = makeValidRequestData()

        let response = try await service.authorizeUser(requestData: request)

        XCTAssertEqual(response.status, "error")
        XCTAssertEqual(response.error, "access_denied")
        XCTAssertEqual(response.errorDescription, "User denied access")
        XCTAssertNil(response.authorizationCode)
        XCTAssertNil(response.authSession)
    }

    func test_authorizeUser_withMissingCode_throwsInteractiveAuthorizationException() async {
        let service = RedirectToWebAuthorizationMethodService { _ in [:] }
        let request = makeValidRequestData()

        do {
            _ = try await service.authorizeUser(requestData: request)
            XCTFail("Expected InteractiveAuthorizationException to be thrown")
        } catch is InteractiveAuthorizationException {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_authorizeUser_withValidCode_returnsSuccessAndAuthSession() async throws {
        let service = RedirectToWebAuthorizationMethodService { _ in
            [
                "code": "authcode123",
                "auth_session": "session456"
            ]
        }
        let request = makeValidRequestData()

        let response = try await service.authorizeUser(requestData: request)

        XCTAssertEqual(response.status, "success")
        XCTAssertEqual(response.authorizationCode, "authcode123")
        XCTAssertEqual(response.authSession, "session456")
        XCTAssertNil(response.error)
        XCTAssertNil(response.errorDescription)
    }

    func test_authorizeUser_passesCorrectAuthorizationUrlToCallback() async throws {
        // Arrange expected inputs
        let authorizeUrl = "https://auth.example.com/authorize"
        let clientId = "my-client"
        let redirectUri = "myapp://callback"
        let scope = "openid email"
        let codeVerifier = "code-verifier"
        let codeChallenge = "code-challenge"
        let state = "state-xyz"
        let nonce = "nonce-abc"

        var capturedUrl: String?
        let service = RedirectToWebAuthorizationMethodService { url in
            capturedUrl = url
            // Return an error so the service returns early; we only care about the URL here.
            return ["error": "access_denied"]
        }

        let request = makeValidRequestData(
            authorizeUrl: authorizeUrl,
            clientId: clientId,
            redirectUri: redirectUri,
            scope: scope,
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge,
            state: state,
            nonce: nonce
        )

        // Act
        _ = try await service.authorizeUser(requestData: request)

        // Assert
        guard let urlString = capturedUrl, let components = URLComponents(string: urlString) else {
            return XCTFail("Expected a valid URL to be passed to OpenWebPageCallback")
        }

        XCTAssertEqual("\(components.scheme ?? "")://\(components.host ?? "")\(components.path)", authorizeUrl)

        let items = components.queryItems ?? []
        let query: [String: String] = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(query["client_id"], clientId)
        XCTAssertEqual(query["redirect_uri"], redirectUri)
        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["scope"], scope)
        XCTAssertEqual(query["state"], state)
        XCTAssertEqual(query["code_challenge"], codeChallenge)
        // Accept either s256 or S256 (implementation may choose case)
        if let method = query["code_challenge_method"] {
            XCTAssertEqual(method.lowercased(), "s256")
        } else {
            XCTFail("Missing code_challenge_method")
        }
        XCTAssertEqual(query["nonce"], nonce)
    }
}

// Dummy class to simulate invalid request data
private final class DummyAuthorizationRequestData: AuthorizationRequestData {}
