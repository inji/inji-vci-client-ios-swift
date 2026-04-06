import XCTest
@testable import VCIClient


final class TrustedIssuerHandlerTests: XCTestCase {
    func testDownloadCredentials_returnsResponse() async throws {
        let mockService = MockAuthorizationCodeFlowService()
        mockService.responseToReturn = CredentialResponse(credential: .init("mock"), credentialIssuer: "mock-issuer", credentialConfigurationId: "mock")
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.resultToReturn = IssuerMetadataResult(
            issuerMetadata: IssuerMetadata(
                credentialIssuer: "issuer",
                credentialEndpoint: "mock",
                credentialFormat: .ldp_vc,
                specVersion: .draft13
            ),
            raw: ["credential": "mock"]
        )

        let handler = TrustedIssuerFlowHandler(authService: mockService, issuerMetadataService: mockIssuerMetadataService)

        let result = try await handler.downloadCredentialsDraft13(
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["code": "auth_code"]})],
            getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer", expiresIn: nil) },
            getProofJwt: { _, _, _ in "jwt" }
        )

        XCTAssertTrue(mockService.didCallRequestCredentials)
        let actualData = try result.toJsonString().data(using: .utf8)
        let actualJson = try JSONSerialization.jsonObject(with: actualData!, options: []) as? [String: Any]

        let expectedJson: [String: Any] = [
            "credential": "mock",
            "credentialIssuer": "mock-issuer",
            "credentialConfigurationId": "mock"
        ]

        XCTAssertEqual(actualJson! as NSDictionary, expectedJson as NSDictionary)

    }

    func testDownloadCredentials_withNonceEndpoint_routesToV1() async throws {
        let mockService = MockAuthorizationCodeFlowService()
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.resultToReturn = IssuerMetadataResult(
            issuerMetadata: IssuerMetadata(
                credentialIssuer: "issuer",
                credentialEndpoint: "mock",
                credentialFormat: .ldp_vc,
                nonceEndpoint: "https://issuer.com/nonce"
            ),
            raw: [:]
        )

        let handler = TrustedIssuerFlowHandler(authService: mockService, issuerMetadataService: mockIssuerMetadataService)

        let result = try await handler.downloadCredentials(
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            authorizationMethods: [],
            getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer") },
            getProofs: { _, _, _ in CredentialRequestProofs(jwt: ["mock-jwt"]) }
        )

        XCTAssertTrue(mockService.didCallRequestCredentials)
        XCTAssertNotNil(result.credentials) // V1 mock returns credentials array
    }

    func testDownloadCredentials_withoutNonceEndpoint_routesToDraft13() async throws {
        let mockService = MockAuthorizationCodeFlowService()
        mockService.responseToReturn = CredentialResponse(
            credential: .init("draft13-credential"),
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock"
        )
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.resultToReturn = IssuerMetadataResult(
            issuerMetadata: IssuerMetadata(
                credentialIssuer: "issuer",
                credentialEndpoint: "mock",
                credentialFormat: .ldp_vc,
                specVersion: .draft13
            ),
            raw: [:]
        )

        let handler = TrustedIssuerFlowHandler(authService: mockService, issuerMetadataService: mockIssuerMetadataService)

        let result = try await handler.downloadCredentials(
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            authorizationMethods: [],
            getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer") },
            getProofs: { _, _, _ in CredentialRequestProofs(jwt: ["mock-jwt"]) }
        )

        XCTAssertTrue(mockService.didCallRequestCredentials)
        XCTAssertEqual(result.credentials?.count, 1)
    }

    func testDeprecatedDraft13Overload_routesThroughDownloadCredentialsDraft13() async throws {
        let mockService = MockAuthorizationCodeFlowService()
        mockService.responseToReturn = CredentialResponse(
            credential: .init("draft13-credential"),
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock"
        )
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.resultToReturn = IssuerMetadataResult(
            issuerMetadata: IssuerMetadata(
                credentialIssuer: "issuer",
                credentialEndpoint: "mock",
                credentialFormat: .ldp_vc,
                specVersion: .draft13
            ),
            raw: [:]
        )

        let handler = TrustedIssuerFlowHandler(
            authService: mockService,
            issuerMetadataService: mockIssuerMetadataService
        )

        let result = try await handler.downloadCredentials(
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            authorizationMethods: [.redirectToWeb(openWebPage: { _ in ["code": "auth_code"] })],
            getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer", expiresIn: nil) },
            getProofJwt: { _, _, _ in "jwt" }
        )

        XCTAssertEqual(result?.credential.value as? String, "draft13-credential")
        XCTAssertTrue(mockService.didCallRequestCredentials)
    }

    func testDownloadCredentials_propagatesError() async {
        let mockAuthorizationCodeFlowService = MockAuthorizationCodeFlowService()
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.resultToReturn = IssuerMetadataResult(
            issuerMetadata: IssuerMetadata(
                credentialIssuer: "issuer",
                credentialEndpoint: "mock",
                credentialFormat: .ldp_vc,
                specVersion: .draft13
            ),
            raw: ["credential": "mock"]
        )
        mockAuthorizationCodeFlowService.shouldThrow = true

        let handler = TrustedIssuerFlowHandler(authService: mockAuthorizationCodeFlowService, issuerMetadataService: mockIssuerMetadataService)

        do {
            _ = try await handler.downloadCredentialsDraft13(
                credentialIssuer: "mock-issuer",
                credentialConfigurationId: "mock",
                clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
                authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["code": "auth_code"]})],
                getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer", expiresIn: nil) },
                getProofJwt: { _, _, _ in "jwt" }
            )
            XCTFail("Expected error but got success")
        } catch let error as VCIClientException {
            XCTAssertEqual(error.code, "VCI-009")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
