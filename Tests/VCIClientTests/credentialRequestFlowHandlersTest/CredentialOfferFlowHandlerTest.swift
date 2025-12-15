import XCTest
@testable import VCIClient
final class CredentialOfferFlowHandlerTests: XCTestCase {

    private func makeMinimalIssuerMetadataResult() -> IssuerMetadataResult {
        return IssuerMetadataResult(
            issuerMetadata: IssuerMetadata(
                credentialIssuer: "aud",
                credentialEndpoint: "https://example.com",
                credentialFormat: .ldp_vc
            ),
            raw: [:]
        )
    }

    private func makeMinimalCredentialResponse() -> CredentialResponse {
        return CredentialResponse(credential: .init("mock-credential"), credentialIssuer: "mock",credentialConfigurationId: "mcok-id")
    }

    func testPreAuthorizedFlow_callsPreAuthFlowService() async throws {
        let offerService = MockCredentialOfferService()
        offerService.offerToReturn = CredentialOffer(
            credentialIssuer: "https://issuer.com",
            credentialConfigurationIds: ["config"],
            grants: CredentialOfferGrants(preAuthorizedGrant: PreAuthCodeGrant(preAuthCode: "test", txCode: nil, authorizationServer: nil, interval: nil), authorizationCodeGrant: nil)
        )

        let issuerService = MockIssuerMetadataService()
        issuerService.resultToReturn = makeMinimalIssuerMetadataResult()

        let preAuthFlowService = MockPreAuthFlowService()
        preAuthFlowService.responseToReturn = makeMinimalCredentialResponse()

        let handler = CredentialOfferFlowHandler(
            credentialOfferService: offerService,
            issuerMetadataService: issuerService,
            preAuthFlowService: preAuthFlowService,
            authorizationCodeFlowService: MockAuthorizationCodeFlowService()
        )

        let result = try await handler.downloadCredentials(
            
            credentialOffer: "offer",
            clientMetadata: ClientMetadata(clientId: "id", redirectUri: "uri"),
            getTxCode: { _,_,_ in "tx-code" },
            authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["authorization_code": "auth_code"]})],
            getTokenResponse: {_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
            getProofJwt: { _, _, _ in "jwt" }
        
        )

        
        XCTAssertTrue(preAuthFlowService.didCallRequest)
    }

    func testAuthorizationCodeFlow_callsAuthCodeFlowService() async throws {
        let offerService = MockCredentialOfferService()
        offerService.offerToReturn = CredentialOffer(
            credentialIssuer: "https://issuer.com",
            credentialConfigurationIds: ["config"],
            grants: CredentialOfferGrants(preAuthorizedGrant: nil, authorizationCodeGrant: AuthorizationCodeGrant(issuerState: nil, authorizationServer: nil))
        )

        let issuerService = MockIssuerMetadataService()
        issuerService.resultToReturn = makeMinimalIssuerMetadataResult()

        let authCodeFlowService = MockAuthorizationCodeFlowService()
        authCodeFlowService.responseToReturn = makeMinimalCredentialResponse()

        let handler = CredentialOfferFlowHandler(
            credentialOfferService: offerService,
            issuerMetadataService: issuerService,
            preAuthFlowService: MockPreAuthFlowService(),
            authorizationCodeFlowService: authCodeFlowService
        )

        let result = try await handler.downloadCredentials(
            
            credentialOffer: "offer",
            clientMetadata: ClientMetadata(clientId: "id", redirectUri: "uri"),
            getTxCode: { _,_,_ in "tx-code" },
            authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["authorization_code": "auth_code"]})],
            getTokenResponse: {_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
            getProofJwt: { _, _, _ in "jwt" }
        )

       
        XCTAssertTrue(authCodeFlowService.didCallRequestCredentials)
    }

    func testTrustCheckBlocksWhenRejected() async {
        let offerService = MockCredentialOfferService()
        offerService.offerToReturn = CredentialOffer(
            credentialIssuer: "https://issuer.com",
            credentialConfigurationIds: ["config"],
            grants: CredentialOfferGrants(preAuthorizedGrant: PreAuthCodeGrant(preAuthCode: "test", txCode: nil, authorizationServer: nil, interval: nil), authorizationCodeGrant: nil)
        )

        let issuerService = MockIssuerMetadataService()
        issuerService.resultToReturn = makeMinimalIssuerMetadataResult()

        let preAuthFlowService = MockPreAuthFlowService()
        preAuthFlowService.responseToReturn = makeMinimalCredentialResponse()

        let handler = CredentialOfferFlowHandler(
            credentialOfferService: offerService,
            issuerMetadataService: issuerService,
            preAuthFlowService: preAuthFlowService,
            authorizationCodeFlowService: MockAuthorizationCodeFlowService()
        )

        do {
            _ = try await handler.downloadCredentials(
                
                credentialOffer: "offer",
                clientMetadata: ClientMetadata(clientId: "id", redirectUri: "uri"),
                getTxCode: { _,_,_ in "tx-code" },
                authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["authorization_code": "auth_code"]})],
                getTokenResponse: {_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
                getProofJwt: { _, _, _ in "jwt" },
                onCheckIssuerTrust: {_,_ in false}
            )
            XCTFail("Expected OfferFetchFailedException")
        } catch let error as CredentialOfferFetchFailedException {
            XCTAssertTrue(error.message.contains("Issuer not trusted by user"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testThrowsWhenNoValidGrant() async {
        let offerService = MockCredentialOfferService()
        offerService.offerToReturn = CredentialOffer(
            credentialIssuer: "https://issuer.com",
            credentialConfigurationIds: ["config"],
            grants: CredentialOfferGrants(preAuthorizedGrant: nil, authorizationCodeGrant: nil)
        )

        let issuerService = MockIssuerMetadataService()
        issuerService.resultToReturn = makeMinimalIssuerMetadataResult()

        let handler = CredentialOfferFlowHandler(
            credentialOfferService: offerService,
            issuerMetadataService: issuerService,
            preAuthFlowService: MockPreAuthFlowService(),
            authorizationCodeFlowService: MockAuthorizationCodeFlowService()
        )

        do {
            _ = try await handler.downloadCredentials(
                
                credentialOffer: "offer",
                clientMetadata: ClientMetadata(clientId: "id", redirectUri: "uri"),
                getTxCode: { _,_,_ in "tx-code" },
                authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["authorization_code": "auth_code"]})],
                getTokenResponse: {_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
                getProofJwt: { _, _, _ in "jwt" }
            )
            XCTFail("Expected OfferFetchFailedException")
        } catch let error as CredentialOfferFetchFailedException {
            XCTAssertTrue(error.message.contains("supported grant type"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testBatchCredentialOffer_throwsError() async {
        let offerService = MockCredentialOfferService()
        offerService.offerToReturn = CredentialOffer(
            credentialIssuer: "https://issuer.com",
            credentialConfigurationIds: ["config1", "config2"],
            grants: CredentialOfferGrants(
                preAuthorizedGrant: PreAuthCodeGrant(
                    preAuthCode: "test",
                    txCode: nil,
                    authorizationServer: nil,
                    interval: nil
                ),
                authorizationCodeGrant: nil
            )
        )

        let issuerService = MockIssuerMetadataService()
        issuerService.resultToReturn = makeMinimalIssuerMetadataResult()

        let preAuthFlowService = MockPreAuthFlowService()
        preAuthFlowService.responseToReturn = makeMinimalCredentialResponse()

        let handler = CredentialOfferFlowHandler(
            credentialOfferService: offerService,
            issuerMetadataService: issuerService,
            preAuthFlowService: preAuthFlowService,
            authorizationCodeFlowService: MockAuthorizationCodeFlowService()
        )

        do {
            _ = try await handler.downloadCredentials(
                credentialOffer: "offer",
                clientMetadata: ClientMetadata(clientId: "id", redirectUri: "uri"),
                getTxCode: { _, _, _ in "tx-code" },
                authorizationMethods: [AuthorizationMethod.redirectToWeb(openWebPage: {_ in ["authorization_code": "auth_code"]})],
                getTokenResponse: { _ in TokenResponse(accessToken: "mock", tokenType: "Bearer") },
                getProofJwt: { _, _, _ in "jwt" }
            )
            XCTFail("Expected CredentialOfferFetchFailedException for batch credential offer")
        } catch let error as DownloadFailedException {
            XCTAssertTrue(error.message.contains("Batch credential request is not supported"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

}
