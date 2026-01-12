import XCTest
import OpenID4VPBridge
@testable import VCIClient

final class InteractiveAuthorizationHandlerTests: XCTestCase {

    // Helpers to build inputs
    private func makeClientMetadata() -> ClientMetadata {
        ClientMetadata(clientId: "client-123", redirectUri: "app://callback")
    }

    private func makePKCE() -> PKCESessionManager.PKCESession {
        PKCESessionManager.PKCESession(codeVerifier: "verifier", codeChallenge: "challenge", state: "state", nonce: "nonce")
    }

    private func makeAuthMethods(
        select: @escaping SelectCredentialsForPresentationCallback,
        sign: @escaping SignVerifiablePresentationCallback
    ) -> [AuthorizationMethod] {
        [.presentationDuringIssuance(selectCredentialsForPresentation: select, signVerifiablePresentation: sign)]
    }

    // MARK: - Success path

    func test_handle_success_openId4VpPresentation_flow() async throws {
        let initialNetwork = MockNetworkManager()

        // Provide a presentation interaction response with type openId4VpPresentation and minimal openid4vp_request
        let presentationJSON: [String: Any] = [
            "status": "require_interaction",
            "type": "openid4vp_presentation",
            "auth_session": "auth-session-1",
            "openid4vp_request": [
                "response_type": "vp_token",
                "response_mode": "iar-post"
            ]
        ]
        let initialBody = try JSONSerialization.data(withJSONObject: presentationJSON)
        initialNetwork.responseBody = String(data: initialBody, encoding: .utf8) ?? ""

        let select: SelectCredentialsForPresentationCallback = { _ in
            return ["cred1": [.ldp_vc: [OpenID4VPAnyCodable("dummy-cred")]]]
        }
        let sign: SignVerifiablePresentationCallback = { _ in
            // Return a dummy signing result map; type erased in tests elsewhere
            return [.ldp_vc: DummyVPTokenSigningResult()]
        }

        let handler = InteractiveAuthorizationHandler(networkManager: initialNetwork)
        let response = try await handler.handle(
            endpoint: "https://issuer.example.com/iar",
            clientMetadata: self.makeClientMetadata(),
            credentialConfigurationId: "cfg-1",
            authorizationMethods: makeAuthMethods(select: select, sign: sign),
            pkceSession: self.makePKCE()
        )

        // Assert final response
        XCTAssertEqual(response.status, "require_interaction")
        XCTAssertEqual(response.authSession, "auth-session-1")
    }

    // MARK: - Failure: extractInteractionType invalid JSON

    func test_handle_extractInteractionType_invalidJSON_throws() async {
        let initialNetwork = MockNetworkManager()
        // Not a JSON string
        initialNetwork.responseBody = "not json"

        let handler = InteractiveAuthorizationHandler(networkManager: initialNetwork)

        await XCTAssertThrowsErrorAsync {
            _ = try await handler.handle(
                endpoint: "https://issuer.example.com/iar",
                clientMetadata: self.makeClientMetadata(),
                credentialConfigurationId: "cfg-1",
                authorizationMethods: [
                    .presentationDuringIssuance(selectCredentialsForPresentation: {_ in [:]}, signVerifiablePresentation: {_ in [:]})
                ],
                pkceSession: self.makePKCE()
            )
        } verify: { error in
            let iae = error as? InteractiveAuthorizationException
            XCTAssertNotNil(iae)
            XCTAssertEqual("Failed to authorize via interaction: Missing 'type' in interaction response from authorization server", iae?.message ?? "")
        }
    }

    // MARK: - Failure: unsupported interaction type

    func test_handle_unsupported_interaction_type_throws() async {
        let initialNetwork = MockNetworkManager()
        let json = ["type": "unknown_type"]
        let data = try! JSONSerialization.data(withJSONObject: json)
        initialNetwork.responseBody = String(data: data, encoding: .utf8) ?? ""

        let handler = InteractiveAuthorizationHandler(networkManager: initialNetwork)

        await XCTAssertThrowsErrorAsync {
            _ = try await handler.handle(
                endpoint: "https://issuer.example.com/iar",
                clientMetadata: self.makeClientMetadata(),
                credentialConfigurationId: "cfg-1",
                authorizationMethods: [
                    .presentationDuringIssuance(selectCredentialsForPresentation: {_ in [:]}, signVerifiablePresentation: {_ in [:]})
                ],
                pkceSession: self.makePKCE()
            )
        } verify: { error in
            let iae = error as? InteractiveAuthorizationException
            XCTAssertNotNil(iae)
            XCTAssertTrue(iae?.message.contains("Unsupported interaction type") == true)
        }
    }

    // MARK: - Failure: deserialize returns nil

    func test_handlePresentationInteraction_deserialize_nil_throws() async {
        let initialNetwork = MockNetworkManager()
        // Body that can't be deserialized to PresentationInteractionResponse
        let json = ["type": InteractionType.openId4VpPresentation.rawValue, "status": "require_interaction"]
        let data = try! JSONSerialization.data(withJSONObject: json)
        initialNetwork.responseBody = String(data: data, encoding: .utf8) ?? ""

        let handler = InteractiveAuthorizationHandler(networkManager: initialNetwork)

        await XCTAssertThrowsErrorAsync {
            _ = try await handler.handle(
                endpoint: "https://issuer.example.com/iar",
                clientMetadata: self.makeClientMetadata(),
                credentialConfigurationId: "cfg-1",
                authorizationMethods: self.makeAuthMethods(select: { _ in [:] }, sign: { _ in [:] }),
                pkceSession: self.makePKCE()
            )
        } verify: { error in
            let iae = error as? InteractiveAuthorizationException
            XCTAssertNotNil(iae)
            XCTAssertTrue(iae?.message.contains("Failed to parse presentation interaction response") == true)
        }
    }

    // MARK: - Failure: validate throws

    func test_handlePresentationInteraction_validate_throws() async {
        let initialNetwork = MockNetworkManager()
        // Provide shape that deserializes but fails validation: missing/invalid openid4vp_request
        let json: [String: Any] = [
            "type": InteractionType.openId4VpPresentation.rawValue,
            "status": "require_interaction",
            "auth_session": "s",
            "openid4vp_request": [:]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        initialNetwork.responseBody = String(data: data, encoding: .utf8) ?? ""

        let handler = InteractiveAuthorizationHandler(networkManager: initialNetwork)

        await XCTAssertThrowsErrorAsync {
            _ = try await handler.handle(
                endpoint: "https://issuer.example.com/iar",
                clientMetadata: self.makeClientMetadata(),
                credentialConfigurationId: "cfg-1",
                authorizationMethods: self.makeAuthMethods(select: { _ in [:] }, sign: { _ in [:] }),
                pkceSession: self.makePKCE()
            )
        } verify: { error in
            let iae = error as? InteractiveAuthorizationException
            XCTAssertNotNil(iae)
            XCTAssertTrue(iae?.message.contains("Invalid presentation interaction response") == true)
        }
    }

    func test_throws_error_during_network_error_on_initial_iar_request() async {
        let initialNetwork = MockNetworkManager()
        initialNetwork.shouldThrowNetworkError = true

        let handler = InteractiveAuthorizationHandler(networkManager: initialNetwork)

        await XCTAssertThrowsErrorAsync {
            _ = try await handler.handle(
                endpoint: "https://issuer.example.com/iar",
                clientMetadata: self.makeClientMetadata(),
                credentialConfigurationId: "cfg-1",
                authorizationMethods: [
                    .presentationDuringIssuance(selectCredentialsForPresentation: {_ in [:]}, signVerifiablePresentation: {_ in [:]})
                ],
                pkceSession: self.makePKCE()
            )
        } verify: { error in
            let iae = error as? InteractiveAuthorizationException
            XCTAssertNotNil(iae)
            XCTAssertEqual("Failed to authorize via interaction: Interactive authorization failed: Failed to download Credential: Simulated network failure", iae?.message ?? "")
        }
    }
}


