
import Foundation
@testable import VCIClient

// MARK: - Mock AuthServerResolver

final class MockAuthServerResolver: AuthorizationServerResolver {
    var mockIssuer: String = "mock-issuer"
    var mockTokenEndpoint: String? = "https://example.com/token"
    var mcokAuthorizationEndpoint: String? = "https://example.com/auth"
    var mockInteractiveAuthorizationEndpoint: String?
    var mockGrantTypesSupported: [String]? = nil
    override func resolveForPreAuth(issuerMetadata: IssuerMetadata, credentialOffer: CredentialOffer) async throws -> AuthorizationServerMetadata {
        return AuthorizationServerMetadata(
            issuer: mockIssuer,
            grantTypesSupported: mockGrantTypesSupported,
            tokenEndpoint: mockTokenEndpoint,
            authorizationEndpoint: nil,
            interactiveAuthorizationEndpoint: mockInteractiveAuthorizationEndpoint
        )
    }

    override func resolveForAuthCode(issuerMetadata: IssuerMetadata,
                                     credentialOffer: CredentialOffer? = nil) async throws -> AuthorizationServerMetadata {
        return AuthorizationServerMetadata(
            issuer: mockIssuer,
            grantTypesSupported: mockGrantTypesSupported,
            tokenEndpoint: mockTokenEndpoint,
            authorizationEndpoint: mcokAuthorizationEndpoint,
            interactiveAuthorizationEndpoint: mockInteractiveAuthorizationEndpoint
        )
    }
}

// MARK: - Mock TokenService

final class MockTokenService: TokenService {
    var authCodeErrorToThrow: Error?
    var preAuthTokenResponse = TokenResponse(
        accessToken: "mock-access-token",
        tokenType: "Bearer",
        expiresIn: 3600,
        cNonce: "mock-cnonce",
        cNonceExpiresIn: 600
    )
    var authCodeTokenResponse = TokenResponse(
        accessToken: "mock-access-token",
        tokenType: "Bearer",
        expiresIn: 3600,
        cNonce: "mock-cnonce",
        cNonceExpiresIn: 600
    )

    override func getAccessToken(getTokenResponse: @escaping TokenResponseCallback,
                                 tokenEndpoint: String,
                                 timeoutMillis: Int64 = Constants.defaultNetworkTimeoutInMillis,
                                 preAuthCode: String,
                                 txCode: String? = nil) async throws -> TokenResponse {
        return preAuthTokenResponse
    }

    override func getAccessToken(getTokenResponse: @escaping TokenResponseCallback,
                                 tokenEndpoint: String,
                                 timeoutMillis: Int64 = Constants.defaultNetworkTimeoutInMillis,
                                 authCode: String,
                                 clientId: String? = nil,
                                 redirectUri: String? = nil,
                                 codeVerifier: String? = nil) async throws -> TokenResponse {
        if let authCodeErrorToThrow {
            throw authCodeErrorToThrow
        }
        return authCodeTokenResponse
    }
}

final class MockNonceService: NonceService {
    var nonceToReturn: String? = "mock-nonce"
    var errorToThrow: Error?

    override func fetchNonce(
        issuerMetadata: IssuerMetadata,
        timeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> String? {
        if let errorToThrow {
            throw errorToThrow
        }
        return nonceToReturn
    }
}

// MARK: - Mock CredentialRequestExecutor

final class MockCredentialRequestExecutor: CredentialRequestExecutor {
    var shouldReturnNil = false
    var errorToThrow: Error?
    var shouldThrow: Bool = false

    init(shouldReturnNil: Bool = false) {
        self.shouldReturnNil = shouldReturnNil
    }

    override func requestCredential(
        issuerMetadata: IssuerMetadata,
        credentialConfigurationId: String,
        proofs: CredentialRequestProofs,
        accessToken: String,
        timeoutInMillis: Int64 = 10000,
        session: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponseSpecVersion1? {
        if shouldReturnNil { return nil }
        if let errorToThrow {
            throw errorToThrow
        }

        return CredentialResponseSpecVersion1(
            credentials: [AnyCodable("mock-credential")],
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock-id"
        )
    }

    override func requestCredentialDraft13(
        issuerMetadata: IssuerMetadata,
        credentialConfigurationId: String,
        proof: Proof,
        accessToken: String,
        timeoutInMillis: Int64 = 10000,
        session: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponse? {
        if shouldReturnNil { return nil }
        if let errorToThrow {
            throw errorToThrow
        }
        if shouldThrow { throw DownloadFailedException("test-error: credential request failed") }
        return CredentialResponse(credential: AnyCodable("mock-credential"), credentialIssuer: "mock-issuer", credentialConfigurationId: "mock-id")
    }
}

final class MockCredentialOfferHandler: CredentialOfferFlowHandler {
    var shouldThrow = false
    var didCallDownload = false

    override func downloadCredentials(
        credentialOffer: String,
        clientMetadata: ClientMetadata,
        getTxCode: TxCodeCallback,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallbackSpecVersion1,
        onCheckIssuerTrust: CheckIssuerTrustCallback = nil,
        networkSession: NetworkManager = NetworkManager.shared,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponseSpecVersion1 {
        didCallDownload = true
        if shouldThrow {
            throw DownloadFailedException("Simulated failure")
        }
        return CredentialResponseSpecVersion1(
            credentials: [AnyCodable("mock-credential")],
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock-id"
        )
    }

    override func downloadCredentialsDraft13(
        credentialOffer: String,
        clientMetadata: ClientMetadata,
        getTxCode: TxCodeCallback,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        onCheckIssuerTrust: CheckIssuerTrustCallback = nil,
        networkSession: NetworkManager = NetworkManager.shared,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse {
        didCallDownload = true
        if shouldThrow {
            throw DownloadFailedException("Simulated failure")
        }
        return CredentialResponse.mock()
    }
}

class MockTrustedIssuerHandler: TrustedIssuerFlowHandler {
    var shouldThrow = false
    var didCallDownload = false

    override func downloadCredentials(
        credentialIssuer: String,
        credentialConfigurationId: String,
        clientMetadata: ClientMetadata,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallbackSpecVersion1,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis,
        networkSession: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponseSpecVersion1? {
        didCallDownload = true
        if shouldThrow {
            throw DownloadFailedException("Simulated failure")
        }
        return CredentialResponseSpecVersion1(
            credentials: [AnyCodable("mock-credential")],
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock-id"
        )
    }

    override func downloadCredentialsDraft13(
        credentialIssuer: String,
        credentialConfigurationId: String,
        clientMetadata: ClientMetadata,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis,
        networkSession: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponse? {
        didCallDownload = true
        if shouldThrow {
            throw DownloadFailedException("Simulated failure")
        }
        return CredentialResponse.mock()
    }
}

final class MockNetworkManager: NetworkManager {
    var responseBody: String = ""
    var shouldThrowNetworkError: Bool = false
    var simulateDelay: TimeInterval = 0
    var capturedParams: [String: String] = [:]
    var responseHeaders: [AnyHashable: Any]?
    var shouldThrowTimeout: Bool = false
    var capturedUrlRequest: URLRequest?

    override func sendRequest(
        url: String,
        method: HttpMethod,
        headers: [String: String]?,
        bodyParams: [String: String]?,
        timeoutMillis: Int64
    ) async throws -> NetworkResponse {
        if simulateDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1000000000))
        }

        if shouldThrowTimeout {
            throw NetworkRequestTimeoutException("Simulated timeout")
        }

        if shouldThrowNetworkError {
            throw DownloadFailedException("Simulated network failure")
        }

        capturedParams = bodyParams ?? [:]
        return NetworkResponse(body: responseBody, headers: nil)
    }

    override func sendRequest(request: URLRequest) async throws -> NetworkResponse {
        if simulateDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1000000000))
        }

        if shouldThrowTimeout {
            throw NetworkRequestTimeoutException("Simulated timeout")
        }
        if shouldThrowNetworkError {
            throw DownloadFailedException("Simulated network failure")
        }

        capturedUrlRequest = request

        return NetworkResponse(
            body: responseBody,
            headers: responseHeaders
        )
    }
}

final class MockAuthServerDiscoveryService: AuthorizationServerDiscoveryService {
    var mockMetadataByUrl: [String: AuthorizationServerMetadata] = [:]
    var urlsThatThrow: Set<String> = []

    override func discover(baseUrl: String) async throws -> AuthorizationServerMetadata {
        if urlsThatThrow.contains(baseUrl) {
            throw AutorizationServerDiscoveryException("Simulated failure for \(baseUrl)")
        }
        guard let metadata = mockMetadataByUrl[baseUrl] else {
            throw AutorizationServerDiscoveryException("No mock available for \(baseUrl)")
        }
        return metadata
    }
}

// MARK: - PKCESession Service

final class MockPKCESessionManager: PKCESessionManager {
    override func createSession() -> PKCESession {
        let codeVerifier = "mock-code"
        let codeChallenge = "mock-challenge"
        let state = "mock-state"
        let nonce = "mock-nonce"
        return PKCESession(
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge,
            state: state,
            nonce: nonce
        )
    }
}

class MockValidCredentialRequest: CredentialRequestProtocol {
    required init(accessToken: String, issuerMetaData: IssuerMetadata, proof: JWTProof) {
    }

    func validateIssuerMetadata() -> ValidatorResult {
        return ValidatorResult(isValid: true)
    }

    func constructRequest() throws -> URLRequest {
        return URLRequest(url: URL(string: "https://example.com")!)
    }
}

class MockInteractiveAuthorizationHandler: InteractiveAuthorizationHandler {
    var responseToReturn = AuthorizationResponse(
        authorizationCode: "dummy",
        status: "success",
        error: nil,
        errorDescription: nil,
        authSession: "dummy"
    )
    var errorToThrow: Error?
    var shouldThrowMissingInteractionType: Bool = false

    override func handle(
        endpoint: String,
        clientMetadata: ClientMetadata,
        credentialConfigurationId: String,
        authorizationMethods: [AuthorizationMethod],
        pkceSession: PKCESessionManager.PKCESession
    ) async throws -> AuthorizationResponse {
        if let errorToThrow {
            throw errorToThrow
        }
        if shouldThrowMissingInteractionType {
            throw DownloadFailedException(message: "dummy", serverErrorCode: "missing_interaction_type")
        }
        return responseToReturn
    }
}

class MockInvalidCredentialRequest: CredentialRequestProtocol {
    required init(accessToken: String, issuerMetaData: IssuerMetadata, proof: JWTProof) {
    }

    func validateIssuerMetadata() -> ValidatorResult {
        let result = ValidatorResult(isValid: false)
        result.invalidFields = ["field1", "field2"]
        return result
    }

    func constructRequest() throws -> URLRequest {
        throw NSError(domain: "", code: -1)
    }
}

// MARK: - Helpers

func mockIssuerMetadata() -> IssuerMetadata {
    return IssuerMetadata(
        credentialIssuer: "",
        credentialEndpoint: "",
        credentialType: [],
        context: nil, credentialFormat: CredentialFormat.ldp_vc,
        doctype: "",
        claims: [:],
        authorizationServers: nil,
        tokenEndpoint: nil,
        nonceEndpoint: nil,
        scope: ""
    )
}

func mockProof() -> Proof {
    return JWTProof(jwt: "")
}

// MARK: - Subclassed Factory to Inject Mocks

class TestableCredentialRequestFactory: CredentialRequestFactoryDraft13 {
    var credentialRequestToReturn: CredentialRequestProtocol!

    override func validateAndConstructCredentialRequest(credentialRequest: CredentialRequestProtocol) throws -> URLRequest {
        let validationResult = credentialRequestToReturn.validateIssuerMetadata()
        if validationResult.isValid {
            return try credentialRequestToReturn.constructRequest()
        } else {
            throw InvalidDataProvidedException("invalid fields: \(validationResult.invalidFields.joined(separator: ", "))")
        }
    }
}

final class MockAuthorizationCodeFlowService: AuthorizationCodeFlowService {
    var didCallRequestCredentials = false
    var shouldThrow = false
    var responseToReturn: CredentialResponse?

    override func requestCredentials(
        issuerMetadata: IssuerMetadata,
        clientMetadata: ClientMetadata,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallbackSpecVersion1,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        credentialOffer: CredentialOffer? = nil,
        downloadTimeOutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis,
        session: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponseSpecVersion1 {
        didCallRequestCredentials = true
        if shouldThrow {
            throw VCIClientException(code: "VCI-009", message: "Simulated error")
        }
        return CredentialResponseSpecVersion1(
            credentials: [AnyCodable("mock-credential")],
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock-id"
        )
    }

    override func requestCredentialsDraft13(
        issuerMetadata: IssuerMetadata,
        clientMetadata: ClientMetadata,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        credentialOffer: CredentialOffer? = nil,
        downloadTimeOutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis,
        session: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponse {
        didCallRequestCredentials = true
        if shouldThrow {
            throw VCIClientException(code: "VCI-009", message: "Simulated error")
        }
        return responseToReturn!
    }
}

final class MockCredentialOfferService: CredentialOfferService {
    var offerToReturn: CredentialOffer!

    override func fetchCredentialOffer(_ offer: String) async throws -> CredentialOffer {
        return offerToReturn
    }
}

final class MockIssuerMetadataService: IssuerMetadataService {
    var resultToReturn: IssuerMetadataResult!
    var shouldThrow: Bool = false
    var configurationsToReturn: [String: Any]?

    override func fetchIssuerMetadataResult(
        credentialIssuer: String,
        credentialConfigurationId: String
    ) async throws -> IssuerMetadataResult {
        return resultToReturn
    }

    override func fetchAndParseIssuerMetadata(from credentialIssuer: String) async throws -> [String: Any] {
        if shouldThrow {
            throw IssuerMetadataFetchException("Mock error")
        }

        return resultToReturn.raw as [String: Any]
    }

    override func fetchCredentialConfigurationsSupported(from credentialIssuer: String) async throws -> [String: Any] {
        if shouldThrow {
            throw IssuerMetadataFetchException("Simulated failure")
        }
        return configurationsToReturn ?? [:]
    }
}

final class MockPreAuthFlowService: PreAuthCodeFlowService {
    var didCallRequest = false
    var responseToReturn: CredentialResponse!

    override func requestCredentials(
        issuerMetadata: IssuerMetadata,
        credentialOffer: CredentialOffer,
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallbackSpecVersion1,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        getTxCode: TxCodeCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponseSpecVersion1 {
        didCallRequest = true
        return CredentialResponseSpecVersion1(
            credentials: [AnyCodable("mock-credential")],
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock-id"
        )
    }

    override func requestCredentialsDraft13(
        issuerMetadata: IssuerMetadata,
        credentialOffer: CredentialOffer,
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        getTxCode: TxCodeCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse {
        didCallRequest = true
        return responseToReturn
    }
}
