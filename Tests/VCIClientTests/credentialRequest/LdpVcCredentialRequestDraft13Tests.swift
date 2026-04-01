import XCTest
@testable import VCIClient

class LdpVcCredentialRequestDraft13Tests: XCTestCase {
    
    var credentialRequest: LdpVcCredentialRequestDraft13!
    let url = URL(string: "https://domain.net/credential")!
    let accessToken = "AccessToken"
    let issuer = IssuerMetadata(credentialIssuer: "https://domain.net",
                            credentialEndpoint: "https://domain.net/credential",
                            credentialType: ["VerifiableCredential"],
                            credentialFormat: .ldp_vc)
    let proofJWT = JWTProof(jwt: "ProofJWT")
    
    override func setUp() {
        super.setUp()
        credentialRequest = LdpVcCredentialRequestDraft13(accessToken: accessToken, issuerMetaData: issuer, proof: proofJWT)
    }
    
    override func tearDown() {
        credentialRequest = nil
        super.tearDown()
    }
    
    func testConstructRequestSuccess() {
        
        
        do {
            let request = try credentialRequest.constructRequest()
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer \(accessToken)")
            XCTAssertNotNil(request.httpBody)
        } catch {
            XCTFail("Error: \(error.localizedDescription)")
        }
    }
    
    func testGenerateRequestBodySuccess() {
        let proofJWT = JWTProof(jwt: "xxxx.yyyy.zzzz")
        let issuer = IssuerMetadata(credentialIssuer: "https://domain.net",
                                credentialEndpoint: "https://domain.net/credential",
                                
                                credentialType: ["VerifiableCredential"],
                                credentialFormat: .ldp_vc)
        
        do {
            let jsonData = try credentialRequest.generateRequestBody(proofJWT: proofJWT, issuer: issuer)
            XCTAssertNotNil(jsonData)
        } catch {
            XCTFail("Error: \(error.localizedDescription)")
        }
    }

    func testCredentialDefinitionInitializationSuccess() {
        let credentialDefinition = CredentialDefinition(type: ["Type"])
        XCTAssertEqual(credentialDefinition.context, ["https://www.w3.org/2018/credentials/v1"])
        XCTAssertEqual(credentialDefinition.type, ["Type"])
    }
    
    func testshouldReturnValidatorResultWithIsValidAsTrueWhenRequiredIssuerMetadataDetailsOfLdpVcAreAvailable() {
        let validationResult = credentialRequest.validateIssuerMetadata()
        
        XCTAssertTrue(validationResult.isValid)
        XCTAssert(validationResult.invalidFields.count==0)
    }
    
    func testshouldReturnValidatorResultWithIsValidAsFalseWithInvalidFieldsWhenRequiredCredentialTypeIsNotAvailableInIssuerMetadata() {
        let issuerMetadataWithoutCredentialType = IssuerMetadata(credentialIssuer: "https://domain.net",
                                credentialEndpoint: "https://domain.net/credential",
                                
                                credentialFormat: .mso_mdoc)
        credentialRequest = LdpVcCredentialRequestDraft13(accessToken: accessToken, issuerMetaData: issuerMetadataWithoutCredentialType, proof: proofJWT)
        
        let validationResult = credentialRequest.validateIssuerMetadata()
        
        XCTAssertFalse(validationResult.isValid)
        XCTAssert(validationResult.invalidFields.elementsEqual(["credentialType"]))
    }
}
