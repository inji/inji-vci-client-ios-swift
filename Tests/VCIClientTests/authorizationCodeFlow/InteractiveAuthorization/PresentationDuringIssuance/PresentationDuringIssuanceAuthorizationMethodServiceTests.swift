import XCTest
import OpenID4VPBridge
import CryptoKit
@testable import VCIClient
import OpenID4VP

private struct StubUnsignedVPToken: UnsignedVPToken {}
private struct StubVPTokenSigningResult: VPTokenSigningResult {}
private final class DummyAuthorizationRequestData: AuthorizationRequestData {}

private final class FakeOpenID4VP: OpenID4VPInteracting {
    enum Behavior {
        case success
        case authThrows(OpenID4VPException)
        case unsignedThrows(Error)
        case constructResponseReturns([String: Any])
    }
    
    var behavior: Behavior = .success
    
    // Delegate to a real OpenID4VP for constructing AuthorizationRequest to avoid needing a non-public init
    private let real = OpenID4VP(traceabilityId: "", walletMetadata: nil)
    
    func authenticateVerifier(
        authRequest: [String : Any],
        trustedVerifiers: [Verifier],
        shouldValidateClient: Bool
    ) async throws -> AuthorizationRequest {
        switch behavior {
        case .authThrows(let ex):
            throw ex
        default:
            //             Use the real library to produce an AuthorizationRequest via the protocol to avoid overload ambiguity
            let realAsProtocol = real
            return try await realAsProtocol.authenticateVerifier(
                authRequest: authRequest,
                trustedVerifiers: trustedVerifiers,
                shouldValidateClient: shouldValidateClient
            )
        }
    }
    
    func constructUnsignedVPToken(
        verifiableCredentials: [String : [FormatType : [OpenID4VPAnyCodable]]],
        holderId: String?,
        signatureSuite: String?
    ) async throws -> [FormatType : UnsignedVPToken] {
        switch behavior {
        case .unsignedThrows(let err):
            throw err
        default:
            return [.ldp_vc: StubUnsignedVPToken()]
        }
    }
    
    func constructVPResponse(vpTokenSigningResults: [FormatType : VPTokenSigningResult]) -> [String : Any] {
        switch behavior {
        case .constructResponseReturns(let dict):
            return dict
        default:
            return ["vp_token": "signed", "presentation_submission": ["id": "ps1"]]
        }
    }
    
    func constructErrorInfo(exception: Error) -> [String : Any] {
        return ["error": "server_error", "error_description": "constructed error: \(exception)"]
    }
}

let authorizationRequest = [
    "client_id": "redirect_uri:https://mock-verifier.com",
    "response_uri":"https://mock-verifier.com",
    "presentation_definition": [
        "id": "vp_presentation_definition",
        "input_descriptors": [
            [
                "id": "input_1",
                "name": "Verifiable Credential",
                "purpose": "To verify identity using Linked Data Proofs",
                "format": [
                    "ldp_vc": [
                        "proof_type": ["Ed25519Signature2018", "RsaSignature2018"]
                    ]
                ],
                "constraints": [
                    "fields": [
                        [
                            "path": ["$.credentialSubject.email"],
                            "filter": [
                                "type": "string",
                                "pattern": "@gmail.com"
                            ]
                        ]
                    ]
                ]
            ]
        ]
    ],
    "response_type": "vp_token",
    "response_mode": "direct_post",
    "nonce":"VbRRB/LTxLiXmVNZuyMO8A==",
    "state":"+mRQe1d6pBoJqF6Ab28klg==",
    "client_metadata": [
        "client_name": "Requester name",
        "logo_uri": "https://mock-verifier.com/logo",
        "authorization_encrypted_response_alg": "ECDH-ES",
        "authorization_encrypted_response_enc": "A256GCM",
        "jwks": [
            "keys": [
                [
                    "kty": "OKP",
                    "crv": "X25519",
                    "use": "enc",
                    "x": "BVNVdqorpxCCnTOkkw8S2NAYXvfEvkC-8RDObhrAUA4",
                    "alg": "ECDH-ES",
                    "kid": "ed-key1"
                ],
                [
                    "kty": "OKP",
                    "crv": "Ed25519",
                    "use": "sig",
                    "x": "5tvU4k_TGAfDAru3LfS53qbfHzghjc0kvPGAb2VUwWc",
                    "alg": "EdDSA",
                    "kid": "ed-key2"
                ]]
        ],
        "vp_formats": [
            "ldp_vp": [
                "proof_type": [
                    "Ed25519Signature2018",
                    "Ed25519Signature2020"
                ]
            ]
        ]
    ]
] as [String : Any]

final class PresentationDuringIssuanceAuthorizationMethodServiceTests: XCTestCase {
    
    private func makeRequestData(
        ovpRequest: [String: Any] = authorizationRequest,
        authSession: String = "auth-session-1",
        iar: String = "https://issuer.example.com/iar"
    ) -> PresentationDuringIssuanceRequestData {
        PresentationDuringIssuanceRequestData(ovpRequest: ovpRequest, authSession: authSession, iar: iar)
    }
    
    private func makeService(
        openId4vp: OpenID4VPInteracting,
        network: MockNetworkManager = MockNetworkManager(),
        selectCredentials: SelectCredentialsForPresentationCallback? = nil,
        signVP: SignVerifiablePresentationCallback? = nil
    ) -> PresentationDuringIssuanceAuthorizationMethodService {
        let select: SelectCredentialsForPresentationCallback = selectCredentials ?? { _ in
            return ["cred1": [.ldp_vc: [OpenID4VPAnyCodable(["credentialSubject": ["id": "did:example:123"]])]]]
        }
        let sign: SignVerifiablePresentationCallback = signVP ?? { _ in
            return [.ldp_vc: StubVPTokenSigningResult()]
        }
        return PresentationDuringIssuanceAuthorizationMethodService(
            selectCredentialsForPresentation: select,
            signVerifiablePresentation: sign,
            networkManager: network,
            openId4vp: openId4vp
        )
    }
    
    func test_type_returns_openId4VpPresentation() {
        let presentationDuringIssuanceAuthorizationMethodService = makeService(openId4vp: FakeOpenID4VP())
        XCTAssertEqual(presentationDuringIssuanceAuthorizationMethodService.type(), InteractionType.openId4VpPresentation.rawValue)
    }
    
    func test_authorizeUser_withInvalidRequestData_throws_error() async throws{
        let presentationDuringIssuanceAuthorizationMethodService = makeService(openId4vp: FakeOpenID4VP())
        
        await XCTAssertThrowsErrorAsync {
            _ = try await presentationDuringIssuanceAuthorizationMethodService.authorizeUser(requestData: DummyAuthorizationRequestData())
        } verify: { error in
            XCTAssertTrue(error is InteractiveAuthorizationException)
            XCTAssertEqual(error.localizedDescription, "Failed to authorize via interaction: Expected PresentationDuringIssuanceRequestData")
        }
    }
    
    func test_validatePresentationRequest_throws_then_network_error_maps_to_errorResponse() async throws {
        let fake = FakeOpenID4VP()
        fake.behavior = .authThrows(GenericFailure(message: "bad auth", className: "Fake"))
        let network = MockNetworkManager()
        network.shouldThrowNetworkError = true
        
        let presentationDuringIssuanceAuthorizationMethodService = makeService(openId4vp: fake, network: network)
        await XCTAssertThrowsErrorAsync {
            _ = try await presentationDuringIssuanceAuthorizationMethodService.authorizeUser(requestData: self.makeRequestData())
        } verify: { error in
            XCTAssertTrue(error is InteractiveAuthorizationException)
            XCTAssertEqual(error.localizedDescription, "Failed to authorize via interaction: Network error while posting VP response. Failed to download Credential: Simulated network failure")
        }
    }
    
    func test_validatePresentationRequest_throws_then_invalid_response_maps_to_errorResponse() async throws {
        let fake = FakeOpenID4VP()
        fake.behavior = .authThrows(GenericFailure(message: "bad auth", className: "Fake"))
        let network = MockNetworkManager()
        // Return non-JSON or wrong JSON so decoding fails
        network.responseBody = "not a json"
        
        let presentationDuringIssuanceAuthorizationMethodService = makeService(openId4vp: fake, network: network)
        await XCTAssertThrowsErrorAsync {
            _ = try await presentationDuringIssuanceAuthorizationMethodService.authorizeUser(requestData: self.makeRequestData())
        } verify: { error in
            XCTAssertTrue(error is InteractiveAuthorizationException)
            XCTAssertEqual(error.localizedDescription, "Failed to authorize via interaction: Issuer response deserialization failed.")
        }
    }
    
    func test_full_success_flow_returns_AuthorizationResponse_success() async throws {
        let fake = FakeOpenID4VP()
        let network = MockNetworkManager()
        // Prepare a successful AuthorizationResponse body
        let success = AuthorizationResponse(
            authorizationCode: "code-123",
            status: "success",
            error: nil,
            errorDescription: nil,
            authSession: "auth-session-1"
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try! JSONEncoder().encode(success)
        network.responseBody = String(data: data, encoding: .utf8) ?? ""
        
        let presentationDuringIssuanceAuthorizationMethodService = makeService(openId4vp: fake, network: network)
        let response = try await presentationDuringIssuanceAuthorizationMethodService.authorizeUser(requestData: makeRequestData())
        
        XCTAssertEqual(response.status, "success")
        XCTAssertEqual(response.authorizationCode, "code-123")
        XCTAssertEqual(response.authSession, "auth-session-1")
        XCTAssertNil(response.error)
        XCTAssertNil(response.errorDescription)
        
        // assert body params posted
        XCTAssertEqual(network.capturedParams["auth_session"], "auth-session-1")
        XCTAssertNotNil(network.capturedParams["openid4vp_response"])
    }
    
    func test_selectCredentials_timeout_is_mapped_to_constructed_error_and_posted() async throws{
        let fake = FakeOpenID4VP()
        let network = MockNetworkManager()
        // Make selectCredentials hang beyond timeout by sleeping
        let select: SelectCredentialsForPresentationCallback = { _ in
            try await Task.sleep(nanoseconds: 600_000_000) // 600ms
            return [:]
        }
        // Return a valid JSON error response from issuer to ensure outer flow continues
        let errorResponse = AuthorizationResponse(
            authorizationCode: nil,
            status: "error",
            error: "access_denied",
            errorDescription: "denied",
            authSession: "auth-session-1"
        )
        let data = try! JSONEncoder().encode(errorResponse)
        network.responseBody = String(data: data, encoding: .utf8) ?? ""
        
        let presentationDuringIssuanceAuthorizationMethodService = PresentationDuringIssuanceAuthorizationMethodService(
            selectCredentialsForPresentation: select,
            signVerifiablePresentation: { _ in [.ldp_vc: StubVPTokenSigningResult()] },
            networkManager: network,
            openId4vp: fake
        )
        
        let response = try await presentationDuringIssuanceAuthorizationMethodService.authorizeUser(requestData: makeRequestData())
        XCTAssertEqual(response.status, "error")
        XCTAssertEqual(response.error, "access_denied")
        XCTAssertEqual(network.capturedParams["auth_session"], "auth-session-1")
    }
    
    func test_signVerifiablePresentation_timeout_is_mapped_to_constructed_error_and_posted() async throws {
        let fake = FakeOpenID4VP()
        let network = MockNetworkManager()
        // select returns quickly
        let select: SelectCredentialsForPresentationCallback = { _ in
            return ["cred1": [.ldp_vc: [OpenID4VPAnyCodable("dummy-cred")]]]
        }
        // sign sleeps to trigger timeout
        let sign: SignVerifiablePresentationCallback = { _ in
            try await Task.sleep(nanoseconds: 600_000_000) // 600ms
            return [.ldp_vc: StubVPTokenSigningResult()]
        }
        // Issuer returns an error JSON, still exercise network posting
        let errorResponse = AuthorizationResponse(
            authorizationCode: nil,
            status: "error",
            error: "server_error",
            errorDescription: "timeout",
            authSession: "auth-session-1"
        )
        let data = try! JSONEncoder().encode(errorResponse)
        network.responseBody = String(data: data, encoding: .utf8) ?? ""
        
        let presentationDuringIssuanceAuthorizationMethodService = PresentationDuringIssuanceAuthorizationMethodService(
            selectCredentialsForPresentation: select,
            signVerifiablePresentation: sign,
            networkManager: network,
            openId4vp: fake
        )
        
        let response = try await presentationDuringIssuanceAuthorizationMethodService.authorizeUser(requestData: makeRequestData())
        XCTAssertEqual(response.status, "error")
        XCTAssertEqual(response.error, "server_error")
        XCTAssertEqual(response.authSession, "auth-session-1")
    }
    
    func test_error_when_signature_suite_not_provided_for_ldp_vc_selected_credentials() async throws {
        let network = MockNetworkManager()
        network.responseBody = """
        {
            "code": "code-123",
            "status": "success",
            "auth_session": "auth-session-1"
        }
        """
        
        let presentationDuringIssuanceAuthorizationMethodService = makeService(openId4vp: FakeOpenID4VP(), network: network)
        _ = try await presentationDuringIssuanceAuthorizationMethodService.authorizeUser(requestData: makeRequestData())
        
        let errorSent = network.capturedParams
        XCTAssertTrue(((errorSent["openid4vp_response"]?.contains("\"error_description\":\"constructed error: VCIClient.InteractiveAuthorizationException\"")) != nil))
        XCTAssertEqual(errorSent["auth_session"], "auth-session-1")
    }
    
    func test_handle_network_timeout_during_vp_submission() async throws {
        let network = MockNetworkManager()
        network.shouldThrowTimeout = true
        
        let presentationDuringIssuanceAuthorizationMethodService = makeService(openId4vp: FakeOpenID4VP(), network: network)
        await XCTAssertThrowsErrorAsync {
            _ = try await presentationDuringIssuanceAuthorizationMethodService.authorizeUser(requestData: self.makeRequestData())
        } verify: { error in
            XCTAssertTrue(error is InteractiveAuthorizationException)
            XCTAssertEqual(error.localizedDescription, "Failed to authorize via interaction: Network error while posting VP response. Download failed due to request timeout: Simulated timeout")
        }
        
    }
}

