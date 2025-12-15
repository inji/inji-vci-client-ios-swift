import XCTest
@testable import VCIClient


final class TrustedIssuerHandlerTests: XCTestCase {
    func testDownloadCredentials_returnsResponse() async throws {
        let mockService = MockAuthorizationCodeFlowService()
        mockService.responseToReturn = CredentialResponse(credential: .init("mock"), credentialIssuer: "mock-issuer", credentialConfigurationId: "mock")
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.resultToReturn = IssuerMetadataResult(issuerMetadata: IssuerMetadata(credentialIssuer: "issuer", credentialEndpoint: "mock", credentialFormat: .ldp_vc), raw: ["credential": "mock"])

        let handler = TrustedIssuerFlowHandler(authService: mockService, issuerMetadataService: mockIssuerMetadataService)

        let result = try await handler.downloadCredentials(
            credentialIssuer: "mock-issuer",
            credentialConfigurationId: "mock",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["authorization_code": "auth_code"]})],
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

    func testDownloadCredentials_propagatesError() async {
        let mockAuthorizationCodeFlowService = MockAuthorizationCodeFlowService()
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.resultToReturn = IssuerMetadataResult(issuerMetadata: IssuerMetadata(credentialIssuer: "issuer", credentialEndpoint: "mock", credentialFormat: .ldp_vc), raw: ["credential": "mock"])
        mockAuthorizationCodeFlowService.shouldThrow = true

        let handler = TrustedIssuerFlowHandler(authService: mockAuthorizationCodeFlowService, issuerMetadataService: mockIssuerMetadataService)

        do {
            _ = try await handler.downloadCredentials(
                credentialIssuer: "mock-issuer",
                credentialConfigurationId: "mock",
                clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
                authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["authorization_code": "auth_code"]})],
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
