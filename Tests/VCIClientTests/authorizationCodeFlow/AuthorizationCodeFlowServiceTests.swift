
@testable import VCIClient
import XCTest
final class AuthorizationCodeFlowServiceTests: XCTestCase {
    func makeService(
        resolver: AuthorizationServerResolver = MockAuthServerResolver(),
        tokenService: TokenService = MockTokenService(),
        executor: CredentialRequestExecutor = MockCredentialRequestExecutor(),
        pkceManager: PKCESessionManager = MockPKCESessionManager()
    ) -> AuthorizationCodeFlowService {
        return AuthorizationCodeFlowService(
            authServerResolver: resolver,
            tokenService: tokenService,
            credentialExecutor: executor,
            pkceSessionManager: pkceManager
        )
    }

    func test_requestCredentials_success() async throws {
        let service = makeService()

        let result = try await service.requestCredentials(
            issuerMetadata: IssuerMetadata.mock(),
            clientMetadata: ClientMetadata(clientId: "client123", redirectUri: "app://redirect"),
            getTokenResponse: {_ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer")},
            getProofJwt: { _, _, _ in "mock-jwt" },
            credentialConfigurationId: "vc1",
            proofSigningAlgorithmsSupportedSupported: ["rs256"]
        )

        XCTAssertEqual(result.credential.value as? String, "mock-credential")
    }

    func test_missingAuthorizationEndpoint_shouldThrow() async {
        let resolver = MockAuthServerResolver()
        resolver.mcokAuthorizationEndpoint = nil

        let service = makeService(resolver: resolver)

        do {
            let result = try await service.requestCredentials(
                issuerMetadata: IssuerMetadata.mock(),
                clientMetadata: ClientMetadata(clientId: "client123", redirectUri: "app://redirect"),
                getTokenResponse: {_ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer")},
                getProofJwt: { _, _, _ in "mock-jwt" },
                credentialConfigurationId: "vc1",
                proofSigningAlgorithmsSupportedSupported: ["rs256"]
            )
            XCTFail("Expected to throw due to missing authorization endpoint")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Missing authorization endpoint"))
        }
    }

    func test_missingTokenEndpoint_shouldThrow() async {
        let resolver = MockAuthServerResolver()
        resolver.mockTokenEndpoint = nil

        let service = makeService(resolver: resolver)

        do {
            let result = try await service.requestCredentials(
                issuerMetadata: IssuerMetadata.mock(),
                clientMetadata: ClientMetadata(clientId: "client123", redirectUri: "app://redirect"),
                getTokenResponse: {_ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer")},
                getProofJwt: { _, _, _ in "mock-jwt" },
                credentialConfigurationId: "vc1",
                proofSigningAlgorithmsSupportedSupported: ["rs256"]
            )
            XCTFail("Expected to throw due to missing token endpoint")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Missing token endpoint"))
        }
    }

    func test_credentialDownloadNil_shouldThrow() async {
        let executor = MockCredentialRequestExecutor(shouldReturnNil: true)
        let service = makeService(executor: executor)

        do {
            _ = try await service.requestCredentials(
                issuerMetadata: IssuerMetadata.mock(),
                clientMetadata: ClientMetadata(clientId: "client123", redirectUri: "app://redirect"),
                getTokenResponse: {_ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer")},
                getProofJwt: { _, _, _ in "mock-jwt" },
                credentialConfigurationId: "vc1",
                proofSigningAlgorithmsSupportedSupported: ["rs256"]
            )
            XCTFail("Expected to throw due to nil credential response")
        } catch {
            print("-------", error.localizedDescription)
            XCTAssertTrue(error.localizedDescription.contains("Credential request returned nil"))
        }
    }
}
