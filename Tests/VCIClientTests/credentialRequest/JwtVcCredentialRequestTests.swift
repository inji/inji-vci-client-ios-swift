import XCTest
@testable import VCIClient

final class JwtVcCredentialRequestTests: XCTestCase {

    var credentialRequest: JwtVcCredentialRequest!
    let accessToken = "AccessToken"
    let proofJWT = JWTProof(jwt: "xxxx.yyyy.zzzz")
    let sampleEndpoint = "https://issuer.example.com/credential"
    let sampleTypes = ["VerifiableCredential", "UniversityDegreeCredential"]

    override func setUp() {
        super.setUp()
        let issuer = IssuerMetadata(
            credentialIssuer: "https://issuer.example.com",
            credentialEndpoint: sampleEndpoint,
            credentialType: sampleTypes, // FIXED: Moved before credentialFormat
            credentialFormat: .jwt_vc_json // FIXED: Likely naming convention
        )
        credentialRequest = JwtVcCredentialRequest(accessToken: accessToken, issuerMetaData: issuer, proof: proofJWT)
    }

    override func tearDown() {
        credentialRequest = nil
        super.tearDown()
    }

    // MARK: - Validation Tests

    func testValidateIssuerMetadata_shouldReturnValid_whenCredentialTypeIsPresent() {
        let result = credentialRequest.validateIssuerMetadata()
        XCTAssertTrue(result.isValid)
    }

    func testValidateIssuerMetadata_shouldReturnInvalid_whenCredentialTypeIsNil() {
        let issuerMissingType = IssuerMetadata(
            credentialIssuer: "https://issuer.example.com",
            credentialEndpoint: sampleEndpoint,
            credentialType: nil, // FIXED: Moved before credentialFormat
            credentialFormat: .jwt_vc_json
        )

        let requestWithMissingType = JwtVcCredentialRequest(accessToken: accessToken, issuerMetaData: issuerMissingType, proof: proofJWT)
        let result = requestWithMissingType.validateIssuerMetadata()

        XCTAssertFalse(result.isValid)
        // Note: Removed message check because ValidatorResult doesn't support it
    }

    // MARK: - Construction Tests

    func testConstructRequest_shouldReturnValidRequest_whenMetadataIsValid() {
        do {
            let request = try credentialRequest.constructRequest()

            XCTAssertEqual(request.url?.absoluteString, sampleEndpoint)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer \(accessToken)")
            XCTAssertNotNil(request.httpBody)

            if let bodyData = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                
                XCTAssertEqual(json["format"] as? String, "jwt_vc_json")
                
                let definition = json["credential_definition"] as? [String: Any]
                XCTAssertNotNil(definition)
                XCTAssertEqual(definition?["type"] as? [String], sampleTypes)
                
                let proof = json["proof"] as? [String: Any]
                XCTAssertEqual(proof?["jwt"] as? String, "xxxx.yyyy.zzzz")
            } else {
                XCTFail("Request body is nil or not convertible to JSON")
            }

        } catch {
            XCTFail("Unexpected error during request construction: \(error)")
        }
    }
}