
@testable import VCIClient
import XCTest
final class PreAuthFlowServiceTests: XCTestCase {
    func makeService(
        resolver: AuthorizationServerResolver = MockAuthServerResolver(),
        tokenService: TokenService = MockTokenService(),
        executor: CredentialRequestExecutor = MockCredentialRequestExecutor()
    ) -> PreAuthCodeFlowService {
        return PreAuthCodeFlowService(
            authServerResolver: resolver,
            tokenService: tokenService,
            credentialExecutor: executor
        )
    }

    func test_requestCredentials_success() async throws {
        let service = makeService()

        let offer = CredentialOffer.mockWithTxCodeRequired()
        
        let result = try await service.requestCredentials(
            issuerMetadata: IssuerMetadata.mock(),
            credentialOffer: offer,
            getTokenResponse:{_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
            getProofJwt: { _, _, _ in "jwt-mock" },
            credentialConfigurationId: "mock-id",
            proofSigningAlgorithmsSupportedSupported: [],
            getTxCode: { _, _, _ in "tx123" }
        )

        XCTAssertEqual(result.credential.value as? String, "mock-credential")
    }

    func test_requestCredentials_missingTokenEndpoint_shouldThrow() async {
        let resolver = MockAuthServerResolver()
        resolver.mockTokenEndpoint = nil

        let service = makeService(resolver: resolver)

        do {
            _ = try await service.requestCredentials(
                issuerMetadata: IssuerMetadata.mock(),
                credentialOffer: CredentialOffer(credentialIssuer: "mock", credentialConfigurationIds: ["mock-id"], grants: nil),
                getTokenResponse:{_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
                getProofJwt: { _, _, _ in "jwt-mock" },
                credentialConfigurationId: "mock-id",
                proofSigningAlgorithmsSupportedSupported: [],
                getTxCode: { _, _, _ in "tx123" }
            )
            XCTFail("Expected failure due to missing token endpoint")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Token endpoint is missing"))
        }
    }

    func test_requestCredentials_txCodeRequiredButNotProvided_shouldThrow() async {
        let service = makeService()

        do {
            _ = try await service.requestCredentials(
                issuerMetadata: IssuerMetadata.mock(),
                credentialOffer: CredentialOffer(credentialIssuer: "mock", credentialConfigurationIds: ["mock-id"], grants: CredentialOfferGrants(preAuthorizedGrant: PreAuthCodeGrant(preAuthCode: "mock-pre-auth", txCode: TxCode(inputMode: nil, length: 2, description: nil), authorizationServer: nil, interval: nil), authorizationCodeGrant: nil)),
                getTokenResponse:{_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
                getProofJwt: { _, _, _ in "jwt-mock" },
                credentialConfigurationId: "mock-id",
                proofSigningAlgorithmsSupportedSupported: []
            )
            XCTFail("Expected failure due to missing tx_code provider")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("tx_code required"))
        }
    }

    func test_requestCredentials_missingGrant_shouldThrow() async {
        let service = makeService()

        _ = CredentialOffer.mockWithoutGrant()

        do {
            _ =
                try await service.requestCredentials(
                    issuerMetadata: IssuerMetadata.mock(),
                    credentialOffer: CredentialOffer(credentialIssuer: "mock", credentialConfigurationIds: ["mock-id"], grants: nil),
                    getTokenResponse:{_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
                    getProofJwt: { _, _, _ in "jwt-mock" },
                    credentialConfigurationId: "mock-id",
                    proofSigningAlgorithmsSupportedSupported: [],
                    getTxCode: { _, _, _ in "tx123" }
                )
            
            XCTFail("Expected failure due to missing grant")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Missing pre-authorized grant details"))
        }
    }

    func test_requestCredentials_credentialDownloadFails_shouldThrow() async {
        let failingExecutor = MockCredentialRequestExecutor(shouldReturnNil: true)
        let service = makeService(executor: failingExecutor)

        do {
            _ = try await service.requestCredentials(
                issuerMetadata: IssuerMetadata.mock(),
                credentialOffer: CredentialOffer(credentialIssuer: "mock", credentialConfigurationIds: ["mock-id"], grants:CredentialOfferGrants(preAuthorizedGrant: PreAuthCodeGrant(preAuthCode: "mock", txCode: nil, authorizationServer: nil, interval: nil), authorizationCodeGrant: nil)),
                getTokenResponse:{_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
                getProofJwt: { _, _, _ in "jwt-mock" },
                credentialConfigurationId: "mock-id",
                proofSigningAlgorithmsSupportedSupported: [],
                getTxCode: { _, _, _ in "tx123" }
            )
            XCTFail("Expected failure due to credential download returning nil")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Credential request failed"))
        }
    }
}
