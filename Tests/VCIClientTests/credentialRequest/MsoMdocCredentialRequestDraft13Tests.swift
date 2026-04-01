@testable import VCIClient
import XCTest

final class MsoMdocCredentialRequestDraft13Test: XCTestCase {
    var credentialRequest: MsoMdocCredentialRequestDraft13!
    let url = URL(string: "https://domain.net/credential")!
    let accessToken = "AccessToken"
    let issuer = IssuerMetadata(credentialIssuer: "https://domain.net",
                                credentialEndpoint: "https://domain.net/credential",
                                credentialFormat: .mso_mdoc,
                                doctype: "org.iso.18013.5.1.mDL"
                                )
    let proofJWT = JWTProof(jwt: "ProofJWT")

    override func setUp() {
        super.setUp()
        credentialRequest = MsoMdocCredentialRequestDraft13(accessToken: accessToken, issuerMetaData: issuer, proof: proofJWT)
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

    func testshouldReturnValidatorResultWithIsValidAsTrueWhenRequiredIssuerMetadataDetailsOfMsoMdocVcAreAvailable() {
        credentialRequest = MsoMdocCredentialRequestDraft13(accessToken: accessToken, issuerMetaData: issuer, proof: proofJWT)

        let validationResult = credentialRequest.validateIssuerMetadata()

        XCTAssertTrue(validationResult.isValid)
        XCTAssert(validationResult.invalidFields.count == 0)
    }

    func testshouldReturnValidatorResultWithIsValidAsFalseWithInvalidFieldsWhenRequiredDocTypeIsNotAvailableInIssuerMetadata() {
        let issuerMetadataWithoutDocType = IssuerMetadata(credentialIssuer: "https://domain.net",
                                                          credentialEndpoint: "https://domain.net/credential",
                                                          credentialFormat: .mso_mdoc)
        credentialRequest = MsoMdocCredentialRequestDraft13(accessToken: accessToken, issuerMetaData: issuerMetadataWithoutDocType, proof: proofJWT)

        let validationResult = credentialRequest.validateIssuerMetadata()

        XCTAssertFalse(validationResult.isValid)
        XCTAssert(validationResult.invalidFields.elementsEqual(["docType"]))
    }
}
