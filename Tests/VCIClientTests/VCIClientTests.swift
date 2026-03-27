
import XCTest
@testable import VCIClient

final class VCIClientTests: XCTestCase {
    func testFetchCredentialUsingCredentialOffer_success() async throws {
        let mockHandler = MockCredentialOfferHandler()
        let client = VCIClient(
            traceabilityId: "test",
            credentialOfferHandler: mockHandler
        )

        let result = try await client.fetchCredentialUsingCredentialOffer(
            credentialOffer: "mock-offer",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            getTxCode: { _, _, _ in "mock-tx-code" },
            authorizationMethods: [
                .redirectToWeb(openWebPage: { _ in ["code": "auth-code"] })
            ],
            getTokenResponse: { _ in TokenResponse(accessToken: "mock", tokenType: "Bearer") },
            getProofJwt: { _, _, _ in "mock-jwt" }
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(mockHandler.didCallDownload)
    }

    func testFetchCredentialUsingCredentialOffer_failure() async {
        let mockHandler = MockCredentialOfferHandler()
        mockHandler.shouldThrow = true
        let client = VCIClient(
            traceabilityId: "test",
            credentialOfferHandler: mockHandler
        )

        await assertThrowsVCIErrorContainingMessage(
            expectedType: VCIClientException.self,
            expectedCode: "VCI-010",
            messageContains: "Simulated failure"
        ) {
            try await client.fetchCredentialUsingCredentialOffer(
                credentialOffer: "mock-offer",
                clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
                getTxCode: { _, _, _ in "mock-tx-code" },
                authorizationMethods: [
                    .redirectToWeb(openWebPage: { _ in ["code": "auth-code"] })
                ],
                getTokenResponse: { _ in TokenResponse(accessToken: "mock", tokenType: "Bearer") },
                getProofJwt: { _, _, _ in "mock-jwt" }
            )
        }
    }

    func testFetchCredentialUsingCredentialOfferV2_success() async throws {
        let mockHandler = MockCredentialOfferHandler()
        let client = VCIClient(
            traceabilityId: "test",
            credentialOfferHandler: mockHandler
        )

        let result = try await client.fetchCredentialUsingCredentialOffer(
            credentialOffer: "mock-offer",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            getTxCode: { _, _, _ in "mock-tx-code" },
            authorizationMethods: [
                .redirectToWeb(openWebPage: { _ in ["code": "auth-code"] })
            ],
            getTokenResponse: { _ in TokenResponse(accessToken: "mock", tokenType: "Bearer") },
            getProofs: { _, _, _ in CredentialRequestProofs(jwt: ["mock-jwt"]) }
        )

        XCTAssertEqual(result?.credentials?.count, 1)
        XCTAssertTrue(mockHandler.didCallDownload)
    }

    func testFetchCredentialFromTrustedIssuer_success() async throws {
        let mockHandler = MockTrustedIssuerHandler()
        let client = VCIClient(
            traceabilityId: "test",
            trustedIssuerFlowHandler: mockHandler
        )

        let result = try await client.fetchCredentialFromTrustedIssuer(
            credentialIssuer: "mock",
            credentialConfigurationId: "mock-id",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer") },
            authorizationMethods: [
                .redirectToWeb(openWebPage: { _ in ["code": "auth-code"] })
            ],
            getProofJwt: { _, _, _ in "mock-jwt" }
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(mockHandler.didCallDownload)
    }

    func testFetchCredentialFromTrustedIssuer_failure() async {
        let mockHandler = MockTrustedIssuerHandler()
        mockHandler.shouldThrow = true
        let client = VCIClient(
            traceabilityId: "test",
            trustedIssuerFlowHandler: mockHandler
        )

        await assertThrowsVCIErrorContainingMessage(
            expectedType: VCIClientException.self,
            expectedCode: "VCI-010",
            messageContains: "Simulated failure"
        ) {
            try await client.fetchCredentialFromTrustedIssuer(
                credentialIssuer: "mock",
                credentialConfigurationId: "mock-id",
                clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
                getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer") },
                authorizationMethods: [
                    .redirectToWeb(openWebPage: { _ in ["code": "auth-code"] })
                ],
                getProofJwt: { _, _, _ in "mock-jwt" }
            )
        }
    }

    func testFetchCredentialFromTrustedIssuerV2_success() async throws {
        let mockHandler = MockTrustedIssuerHandler()
        let client = VCIClient(
            traceabilityId: "test",
            trustedIssuerFlowHandler: mockHandler
        )

        let result = try await client.fetchCredentialFromTrustedIssuer(
            credentialIssuer: "mock",
            credentialConfigurationId: "mock-id",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer") },
            authorizationMethods: [
                .redirectToWeb(openWebPage: { _ in ["code": "auth-code"] })
            ],
            getProofs: { _, _, _ in CredentialRequestProofs(jwt: ["mock-jwt"]) }
        )

        XCTAssertEqual(result?.credentials?.count, 1)
        XCTAssertTrue(mockHandler.didCallDownload)
    }

    func testRequestCredentialByCredentialOffer_success() async throws {
        let mockHandler = MockCredentialOfferHandler()
        let client = VCIClient(
            traceabilityId: "test",
            credentialOfferHandler: mockHandler
        )
        
        let result = try await client.requestCredentialByCredentialOffer(
            credentialOffer: "mock-offer",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""), getTxCode: {_,_,_ in "mock-tx-code"},
            authorizeUser: { _ in "auth-code" },
            getTokenResponse: {_ in TokenResponse(accessToken: "mock", tokenType: "Bearer")},
            getProofJwt: { _, _, _ in "mock-jwt" }
        )
        
        XCTAssertNotNil(result)
        XCTAssertTrue(mockHandler.didCallDownload)
    }
    
    func testRequestCredentialByCredentialOffer_failure() async {
        let mockHandler = MockCredentialOfferHandler()
        mockHandler.shouldThrow = true

        let client = VCIClient(
            traceabilityId: "test",
            credentialOfferHandler: mockHandler
        )

        await assertThrowsVCIErrorContainingMessage(
            expectedType: VCIClientException.self,
            expectedCode: "VCI-010",
            messageContains: "Simulated failure"
        ) {
            try await client.requestCredentialByCredentialOffer(
                credentialOffer: "mock-offer",
                clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
                getTxCode: { _,_,_ in "mock-tx-code" },
                authorizeUser: { _ in "auth-code" },
                getTokenResponse: { _ in TokenResponse(accessToken: "mock", tokenType: "Bearer") },
                getProofJwt: { _, _, _ in "mock-jwt" }
            )
        }
    }

    
    func testRequestCredentialFromTrustedIssuer_success() async throws {
        let mockHandler = MockTrustedIssuerHandler()
        let client = VCIClient(
            traceabilityId: "test",
            trustedIssuerFlowHandler: mockHandler
        )
        
        let result = try await client.requestCredentialFromTrustedIssuer(
            credentialIssuer: "mock",
            credentialConfigurationId: "mock-id",
            clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
            authorizeUser: {_ in "auth_code"},
            getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer")},
            getProofJwt: { _, _, _ in "mock-jwt" }
        )
        
        XCTAssertNotNil(result)
        XCTAssertTrue(mockHandler.didCallDownload)
    }
    
    func testRequestCredentialFromTrustedIssuer_failure() async {
        let mockHandler = MockTrustedIssuerHandler()
        mockHandler.shouldThrow = true

        let client = VCIClient(
            traceabilityId: "test",
            trustedIssuerFlowHandler: mockHandler
        )

        await assertThrowsVCIErrorContainingMessage(
            expectedType: VCIClientException.self,
            expectedCode: "VCI-010",
            messageContains: "Simulated failure"
        ) {
            try await client.requestCredentialFromTrustedIssuer(
                credentialIssuer: "mock",
                credentialConfigurationId: "mock-id",
                clientMetadata: ClientMetadata(clientId: "", redirectUri: ""),
                authorizeUser: { _ in "auth_code" },
                getTokenResponse: { _ in TokenResponse(accessToken: "mock-token", tokenType: "Bearer") },
                getProofJwt: { _, _, _ in "mock-jwt" }
            )
        }
    }

    
    
    
    func testDeprecatedRequestCredential_success() async throws {
        let mockNetwork = MockNetworkManager()
        // Return a valid JSON body for CredentialResponse
        mockNetwork.responseBody = "{\"credential\":\"test\"}"
        
        let client = VCIClient(
            traceabilityId: "test",
            networkSession: mockNetwork
        )
        
        let issuerMeta = IssuerMeta(
            credentialAudience: "aud",
            credentialEndpoint: "https://example.com",
            downloadTimeoutInMilliseconds: 5000, credentialType: ["test"],
            credentialFormat: .ldp_vc,
            docType: nil,
            claims: [:]
        )
        
        let proof = JWTProof(jwt: "mock-jwt")
        
        let result = try await client.requestCredential(
            issuerMeta: issuerMeta,
            proof: proof,
            accessToken: "token"
        )
        
        XCTAssertNotNil(result)
        // Optionally check parsed value
        XCTAssertEqual(result?.credential.value as? String, "test")
    }
    
    func testDeprecatedRequestCredential_failure_invalidJSON() async {
        let mockNetwork = MockNetworkManager()
        mockNetwork.responseBody = "{invalid json}"

        let client = VCIClient(
            traceabilityId: "test",
            networkSession: mockNetwork
        )

        let issuerMeta = IssuerMeta(
            credentialAudience: "aud",
            credentialEndpoint: "https://example.com",
            downloadTimeoutInMilliseconds: 5000,
            credentialType: ["test"],
            credentialFormat: .ldp_vc,
            docType: nil,
            claims: [:]
        )

        let proof = JWTProof(jwt: "mock-jwt")

        await assertThrowsVCIErrorContainingMessage(
            expectedType: DownloadFailedException.self,
            messageContains: "The data couldn’t be read because it isn’t in the correct format"
        ) {
            try await client.requestCredential(
                issuerMeta: issuerMeta,
                proof: proof,
                accessToken: "token"
            )
        }
    }

    
    func testDeprecatedRequestCredential_failure_networkError() async {
        let mockNetwork = MockNetworkManager()
        mockNetwork.shouldThrowNetworkError = true

        let client = VCIClient(
            traceabilityId: "test",
            networkSession: mockNetwork
        )

        let issuerMeta = IssuerMeta(
            credentialAudience: "aud",
            credentialEndpoint: "https://example.com",
            downloadTimeoutInMilliseconds: 5000,
            credentialType: ["test"],
            credentialFormat: .ldp_vc,
            docType: nil,
            claims: [:]
        )

        let proof = JWTProof(jwt: "mock-jwt")

        await assertThrowsVCIErrorContainingMessage(
            expectedType: DownloadFailedException.self,
            messageContains: "Simulated network failure"
        ) {
            try await client.requestCredential(
                issuerMeta: issuerMeta,
                proof: proof,
                accessToken: "token"
            )
        }
    }

    
    func testGetIssuerMetadata_success() async throws {
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.resultToReturn = IssuerMetadataResult(issuerMetadata: IssuerMetadata(credentialIssuer: "mock", credentialEndpoint: "mock", credentialFormat: .ldp_vc), raw: ["issuerName": "TestIssuer"])
        
        let client = VCIClient(
            traceabilityId: "test",
            issuerMetadataService: mockIssuerMetadataService
        )
        
        let result = try await client.getIssuerMetadata(credentialIssuer: "https://issuer.example.com")
        
        XCTAssertEqual(result["issuerName"] as? String, "TestIssuer")
    }
    
    func testGetIssuerMetadata_failure() async {
        let mockIssuerMetadataService = MockIssuerMetadataService(session: MockNetworkManager())
        mockIssuerMetadataService.shouldThrow = true

        let client = VCIClient(
            traceabilityId: "test",
            issuerMetadataService: mockIssuerMetadataService
        )

        await assertThrowsVCIErrorContainingMessage(
            expectedType: VCIClientException.self,
            expectedCode: "VCI-010",
            messageContains: "Mock error"
        ) {
            try await client.getIssuerMetadata(credentialIssuer: "https://issuer.example.com")
        }
    }

    
    func testFetchCredentialConfigurationsSupported_success() async throws {
        let mockService = MockIssuerMetadataService(session: MockNetworkManager())
        mockService.configurationsToReturn = [
            "vc1": ["format": "ldp_vc"],
            "vc2": ["format": "mso_mdoc", "doctype": "org.iso.18013.5.1.mDL"]
        ]
        
        let client = VCIClient(
            traceabilityId: "test",
            issuerMetadataService: mockService
        )
        
        let configs = try await client.getCredentialConfigurationsSupported(
            credentialIssuer: "https://issuer.example.com"
        )
        
        XCTAssertEqual(configs.count, 2)
        XCTAssertEqual((configs["vc1"] as? [String: Any])?["format"] as? String, "ldp_vc")
        XCTAssertEqual((configs["vc2"] as? [String: Any])?["doctype"] as? String, "org.iso.18013.5.1.mDL")
    }
    
    
    func testFetchCredentialConfigurationsSupported_failure_shouldThrow() async {
        let mockService = MockIssuerMetadataService(session: MockNetworkManager())
        mockService.shouldThrow = true
    
        let client = VCIClient(
            traceabilityId: "test",
            issuerMetadataService: mockService
        )
        
        _ = await assertThrowsVCIErrorContainingMessage(
            expectedType: VCIClientException.self,
            expectedCode: "VCI-010",
            messageContains: "Simulated failure"){
                try await client.getCredentialConfigurationsSupported(
                    credentialIssuer: "https://issuer.example.com"
                )
            }
        }
    }

    func testDeprecatedRequestCredential_failure_timeout() async {
        let mockNetwork = MockNetworkManager()
        mockNetwork.shouldThrowTimeout = true

        let client = VCIClient(
            traceabilityId: "test",
            networkSession: mockNetwork
        )

        let issuerMeta = IssuerMeta(
            credentialAudience: "aud",
            credentialEndpoint: "https://example.com",
            downloadTimeoutInMilliseconds: 5000,
            credentialType: ["test"],
            credentialFormat: .ldp_vc,
            docType: nil,
            claims: [:]
        )

        await assertThrowsVCIErrorContainingMessage(
            expectedType: NetworkRequestTimeoutException.self,
            messageContains: "Simulated timeout"
        ) {
            try await client.requestCredential(
                issuerMeta: issuerMeta,
                proof: JWTProof(jwt: "mock-jwt"),
                accessToken: "token"
            )
        }
    }

    func testDeprecatedRequestCredential_emptyBody_returnsNil() async throws {
        let mockNetwork = MockNetworkManager()
        mockNetwork.responseBody = ""

        let client = VCIClient(
            traceabilityId: "test",
            networkSession: mockNetwork
        )

        let issuerMeta = IssuerMeta(
            credentialAudience: "aud",
            credentialEndpoint: "https://example.com",
            downloadTimeoutInMilliseconds: 5000,
            credentialType: ["test"],
            credentialFormat: .ldp_vc,
            docType: nil,
            claims: [:]
        )

        let result = try await client.requestCredential(
            issuerMeta: issuerMeta,
            proof: JWTProof(jwt: "mock-jwt"),
            accessToken: "token"
        )

        XCTAssertNil(result)
    }
