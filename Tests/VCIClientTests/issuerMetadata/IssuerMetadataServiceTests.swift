
import XCTest
@testable import VCIClient
final class IssuerMetadataSpecVersionTests: XCTestCase {
    func testSpecVersion_withNonceEndpoint_returnsV1() {
        let metadata = IssuerMetadata(
            credentialIssuer: "issuer",
            credentialEndpoint: "https://example.com/credential",
            credentialFormat: .ldp_vc,
            nonceEndpoint: "https://example.com/nonce"
        )
        XCTAssertEqual(metadata.specVersion, .v1)
    }

    func testSpecVersion_defaultsToV1WhenUnspecified() {
        let metadata = IssuerMetadata(
            credentialIssuer: "issuer",
            credentialEndpoint: "https://example.com/credential",
            credentialFormat: .ldp_vc
        )
        XCTAssertEqual(metadata.specVersion, .v1)
    }

    func testSpecVersion_canBeExplicitlyMarkedAsDraft13() {
        let metadata = IssuerMetadata(
            credentialIssuer: "issuer",
            credentialEndpoint: "https://example.com/credential",
            credentialFormat: .ldp_vc,
            specVersion: .draft13
        )
        XCTAssertEqual(metadata.specVersion, .draft13)
    }
}

final class IssuerMetadataServiceTests: XCTestCase {

    func makeService(response: String, shouldThrow: Bool = false) -> IssuerMetadataService {
        let mock = MockNetworkManager()
        mock.responseBody = response
        mock.shouldThrowNetworkError = shouldThrow
        return IssuerMetadataService(session: mock)
    }

    func test_fetch_mso_mdoc_success() async throws {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "credential_configurations_supported": {
            "mdoc": {
              "format": "mso_mdoc",
              "doctype": "org.iso.18013.5.1.mDL",
              "claims": {
                "name": "John",
                "dob": "1990-01-01"
              }
            }
          }
        }
        """

        let service = makeService(response: json)
        let result = try await service.fetchIssuerMetadataResult(credentialIssuer: "https://issuer.com", credentialConfigurationId: "mdoc")

        XCTAssertEqual(result.issuerMetadata.credentialIssuer, "https://issuer.com")
        XCTAssertEqual(result.issuerMetadata.credentialFormat, .mso_mdoc)
        XCTAssertEqual(result.issuerMetadata.doctype, "org.iso.18013.5.1.mDL")
    }

    func test_fetch_ldp_vc_success_with_scope() async throws {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "authorization_servers": ["https://auth.issuer.com"],
          "credential_configurations_supported": {
            "vc1": {
              "format": "ldp_vc",
              "scope": "identity",
              "credential_definition": {
                "type": ["VerifiableCredential", "ProfileCredential"],
                "@context": ["https://www.w3.org/2018/credentials/v1"]
              }
            }
          }
        }
        """

        let service = makeService(response: json)
        let result = try await service.fetchIssuerMetadataResult(credentialIssuer:  "https://issuer.com", credentialConfigurationId: "vc1")

        XCTAssertEqual(result.issuerMetadata.credentialIssuer, "https://issuer.com")
        XCTAssertEqual(result.issuerMetadata.credentialFormat, .ldp_vc)
        XCTAssertEqual(result.issuerMetadata.credentialType, ["VerifiableCredential", "ProfileCredential"])
        XCTAssertEqual(result.issuerMetadata.scope, "identity")
        XCTAssertEqual(result.issuerMetadata.authorizationServers, ["https://auth.issuer.com"])
    }

    func test_fetch_ldp_vc_withoutNonceEndpoint_usesDraft13WhenConfigurationHasDisplayHint() async throws {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "credential_configurations_supported": {
            "vc1": {
              "format": "ldp_vc",
              "display": [
                {
                  "name": "Profile Credential"
                }
              ],
              "credential_definition": {
                "type": ["VerifiableCredential", "ProfileCredential"],
                "@context": ["https://www.w3.org/2018/credentials/v1"]
              }
            }
          }
        }
        """

        let service = makeService(response: json)
        let result = try await service.fetchIssuerMetadataResult(
            credentialIssuer: "https://issuer.com",
            credentialConfigurationId: "vc1"
        )

        XCTAssertEqual(result.issuerMetadata.specVersion, .draft13)
    }

    func test_fetch_emptyResponse_shouldThrow() async {
        let service = makeService(response: "")

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "response is empty"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "vc1"
            )
        }
    }



    func test_fetch_missingCredentialConfiguration_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential"
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "credential configuration"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "vc1"
            )
        }
    }


    func test_fetch_missingFormat_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "credential_configurations_supported": {
            "vc1": {
              "scope": "identity"
            }
          }
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "credential format"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "vc1"
            )
        }
    }


    func test_fetch_missingDoctypeInMdoc_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "credential_configurations_supported": {
            "mdoc": {
              "format": "mso_mdoc"
            }
          }
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "Missing doctype"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "mdoc"
            )
        }
    }

    func test_fetch_invalidFormat_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "credential_configurations_supported": {
            "conf1": {
              "format": "unsupported_format"
            }
          }
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "credential format"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "conf1"
            )
        }
    }

    func test_fetch_credentialIssuerMismatch_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://other.issuer.com",
          "credential_endpoint": "https://other.issuer.com/credential",
          "credential_configurations_supported": {
            "vc1": {
              "format": "ldp_vc",
              "credential_definition": {
                "type": ["VerifiableCredential"],
                "@context": ["https://www.w3.org/2018/credentials/v1"]
              }
            }
          }
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "credential_issuer mismatch"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "vc1"
            )
        }
    }

    func test_fetchCredentialConfigurationsSupported_credentialIssuerMismatch_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://other.issuer.com",
          "credential_configurations_supported": {
            "vc1": {
              "format": "ldp_vc"
            }
          }
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "credential_issuer mismatch"
        ) {
            try await service.fetchCredentialConfigurationsSupported(from: "https://issuer.com")
        }
    }

    func test_fetch_networkFailure_shouldThrow() async {
        let service = makeService(response: "{}", shouldThrow: true)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "Simulated network failure"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "vc1"
            )
        }
    }

    
    func testFetch_shouldReturnSdJwtMetadata_whenValidJsonIsProvided() async throws {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "authorization_servers": ["https://auth.issuer.com"],
          "credential_configurations_supported": {
            "vc_sd": {
              "format": "vc+sd-jwt",
              "vct": "IdentityCredential",
              "scope": "identity",
              "claims": {
                "given_name": {
                  "display": [
                    {
                      "name": "Given Name",
                      "locale": "en-US"
                    },
                    {
                      "name": "Vorname",
                      "locale": "de-DE"
                    }
                  ]
                }
              }
            }
          }
        }
        """

        let service = makeService(response: json)
        let result = try await service.fetchIssuerMetadataResult(
            credentialIssuer: "https://issuer.com",
            credentialConfigurationId: "vc_sd"
        )

        let metadata = result.issuerMetadata
        XCTAssertEqual(metadata.credentialIssuer, "https://issuer.com")
        XCTAssertEqual(metadata.credentialEndpoint, "https://issuer.com/credential")
        XCTAssertEqual(metadata.credentialFormat, .vc_sd_jwt)
        XCTAssertEqual(metadata.vct, "IdentityCredential")
        XCTAssertEqual(metadata.scope, "identity")
        XCTAssertEqual(metadata.authorizationServers, ["https://auth.issuer.com"])

        
        let givenNameClaim = metadata.claims?["given_name"]?.value as? [String: Any]
    }
    
    func testFetch_shouldThrow_whenVctIsMissingInSdJwtConfiguration() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "credential_configurations_supported": {
            "vc_sd": {
              "format": "vc+sd-jwt",
              "scope": "identity",
              "claims": {
                "given_name": {
                  "display": [
                    {
                      "name": "Given Name",
                      "locale": "en-US"
                    }
                  ]
                }
              }
            }
          }
        }
        """

        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "Missing vct"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "vc_sd"
            )
        }
    }

    
    func testFetch_shouldReturnDcSdJwtMetadata_whenValidJsonIsProvided() async throws {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "authorization_servers": ["https://auth.issuer.com"],
          "credential_configurations_supported": {
            "dc_sd": {
              "format": "dc+sd-jwt",
              "vct": "DocumentCredential",
              "scope": "identity",
              "claims": {
                "document_id": {
                  "display": [
                    {
                      "name": "Document ID",
                      "locale": "en-US"
                    }
                  ]
                }
              }
            }
          }
        }
        """

        let service = makeService(response: json)
        let result = try await service.fetchIssuerMetadataResult(
            credentialIssuer: "https://issuer.com",
            credentialConfigurationId: "dc_sd"
        )

        let metadata = result.issuerMetadata
        XCTAssertEqual(metadata.credentialIssuer, "https://issuer.com")
        XCTAssertEqual(metadata.credentialEndpoint, "https://issuer.com/credential")
        XCTAssertEqual(metadata.credentialFormat, .dc_sd_jwt)
        XCTAssertEqual(metadata.vct, "DocumentCredential")
        XCTAssertEqual(metadata.scope, "identity")
        XCTAssertEqual(metadata.authorizationServers, ["https://auth.issuer.com"])
    }
    
    func testFetch_shouldThrow_whenVctIsMissingInDcSdJwtConfiguration() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_endpoint": "https://issuer.com/credential",
          "credential_configurations_supported": {
            "dc_sd": {
              "format": "dc+sd-jwt",
              "scope": "identity",
              "claims": {
                "document_id": {
                  "display": [
                    {
                      "name": "Document ID",
                      "locale": "en-US"
                    }
                  ]
                }
              }
            }
          }
        }
        """

        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "Missing vct"
        ) {
            try await service.fetchIssuerMetadataResult(
                credentialIssuer: "https://issuer.com",
                credentialConfigurationId: "dc_sd"
            )
        }
    }

    
    func test_fetchCredentialConfigurationsSupported_success() async throws {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_configurations_supported": {
            "vc1": {
              "format": "ldp_vc"
            },
            "vc2": {
              "format": "mso_mdoc",
              "doctype": "org.iso.18013.5.1.mDL"
            }
          }
        }
        """
        let service = makeService(response: json)
        let configs = try await service.fetchCredentialConfigurationsSupported(from: "https://issuer.com")
        
        XCTAssertEqual(configs.count, 2)
        XCTAssertNotNil(configs["vc1"])
        XCTAssertEqual((configs["vc1"] as? [String: Any])?["format"] as? String, "ldp_vc")
    }

    func test_fetchCredentialConfigurationsSupported_missingBlock_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com"
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "credential_configurations_supported"
        ) {
            try await service.fetchCredentialConfigurationsSupported(from: "https://issuer.com")
        }
    }

    func test_fetchCredentialConfigurationsSupported_emptyBlock_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_configurations_supported": {}
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "empty"
        ) {
            try await service.fetchCredentialConfigurationsSupported(from: "https://issuer.com")
        }
    }

    func test_fetchCredentialConfigurationsSupported_invalidConfigStructure_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_configurations_supported": {
            "vc1": "not a dictionary"
          }
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "Invalid configuration format"
        ) {
            try await service.fetchCredentialConfigurationsSupported(from: "https://issuer.com")
        }
    }

    func test_fetchCredentialConfigurationsSupported_missingFormat_shouldThrow() async {
        let json = """
        {
          "credential_issuer": "https://issuer.com",
          "credential_configurations_supported": {
            "vc1": {
              "scope": "identity"
            }
          }
        }
        """
        let service = makeService(response: json)

        await assertThrowsVCIErrorContainingMessage(
            expectedType: IssuerMetadataFetchException.self,
            messageContains: "Missing 'format'"
        ) {
            try await service.fetchCredentialConfigurationsSupported(from: "https://issuer.com")
        }
    }

}
