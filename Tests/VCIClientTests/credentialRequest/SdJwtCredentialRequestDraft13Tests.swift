import XCTest
@testable import VCIClient

final class SdJwtCredentialRequestDraft13Tests: XCTestCase {

    var credentialRequest: SdJwtCredentialRequestDraft13!
    let accessToken = "AccessToken"
    let proofJWT = JWTProof(jwt: "xxxx.yyyy.zzzz")

    override func setUp() {
        super.setUp()
        let issuer = IssuerMetadata(
            credentialIssuer: "https://issuer.example.com",
            credentialEndpoint: "https://issuer.example.com/credential",
            credentialFormat: .vc_sd_jwt,
            vct: "IdentityCredential"
        )
        credentialRequest = SdJwtCredentialRequestDraft13(accessToken: accessToken, issuerMetaData: issuer, proof: proofJWT)
    }

    override func tearDown() {
        credentialRequest = nil
        super.tearDown()
    }

    func testConstructRequest_shouldReturnValidRequest_whenMetadataIsValid() {
        do {
            let request = try credentialRequest.constructRequest()

            XCTAssertEqual(request.url?.absoluteString, "https://issuer.example.com/credential")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer \(accessToken)")
            XCTAssertNotNil(request.httpBody)

            if let bodyData = request.httpBody,
               let bodyString = String(data: bodyData, encoding: .utf8) {
                XCTAssertTrue(bodyString.contains("\"vct\":\"IdentityCredential\""))
                XCTAssertTrue(bodyString.contains("\"jwt\":\"xxxx.yyyy.zzzz\""))
            } else {
                XCTFail("Request body is nil or not convertible to string")
            }

        } catch {
            XCTFail("Unexpected error during request construction: \(error)")
        }
    }

    func testConstructRequest_shouldThrow_whenVctIsMissing() {
        let issuerMissingVct = IssuerMetadata(
            credentialIssuer: "https://issuer.example.com",
            credentialEndpoint: "https://issuer.example.com/credential",
            credentialFormat: .vc_sd_jwt,
            claims: ["family_name": AnyCodable("Paul")]
        )

        let requestWithMissingVct = SdJwtCredentialRequestDraft13(accessToken: accessToken, issuerMetaData: issuerMissingVct, proof: proofJWT)

        XCTAssertThrowsError(try requestWithMissingVct.constructRequest()) { error in
            guard let downloadError = error as? DownloadFailedException else {
                return XCTFail("Expected DownloadFailedException but got \(type(of: error))")
            }
            XCTAssertTrue(downloadError.localizedDescription.contains("Missing 'vct'"))
        }
    }

    func testValidateIssuerMetadata_shouldReturnValid_whenVctIsPresent() {
        let result = credentialRequest.validateIssuerMetadata()
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.invalidFields.isEmpty)
    }

    func testValidateIssuerMetadata_shouldReturnInvalid_whenVctIsMissing() {
        let issuerMissingVct = IssuerMetadata(
            credentialIssuer: "https://issuer.example.com",
            credentialEndpoint: "https://issuer.example.com/credential",
            credentialFormat: .vc_sd_jwt
        )

        let requestWithMissingVct = SdJwtCredentialRequestDraft13(accessToken: accessToken, issuerMetaData: issuerMissingVct, proof: proofJWT)
        let result = requestWithMissingVct.validateIssuerMetadata()

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.invalidFields, ["vct"])
    }
    
    func testConstructRequest_shouldWorkForBothSdJwtFormats() throws {
        for format in [CredentialFormat.vc_sd_jwt, CredentialFormat.dc_sd_jwt] {
            let issuer = IssuerMetadata(
                credentialIssuer: "https://issuer.com",
                credentialEndpoint: "https://issuer.com/credential",
                credentialFormat: format,
                vct: "SomeCredential"
            )
            
            let request = SdJwtCredentialRequestDraft13(
                accessToken: accessToken,
                issuerMetaData: issuer,
                proof: proofJWT
            )
            
            let httpRequest = try request.constructRequest()

            XCTAssertEqual(httpRequest.httpMethod, "POST")
            XCTAssertEqual(httpRequest.url?.absoluteString, "https://issuer.com/credential")
            
            
            let headers = httpRequest.allHTTPHeaderFields
            XCTAssertEqual(headers?["Content-Type"], "application/json")
            XCTAssertEqual(headers?["Authorization"], "Bearer \(accessToken)")
            XCTAssertEqual(headers?.count, 2)

            
            guard let body = httpRequest.httpBody else {
                return XCTFail("Missing HTTP body for format \(format)")
            }

            let json = try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
            XCTAssertEqual(json?["vct"] as? String, "SomeCredential")
            
            let proof = json?["proof"] as? [String: Any]
            XCTAssertEqual(proof?["jwt"] as? String, "xxxx.yyyy.zzzz")

            let claims = json?["claims"] as? [String: Any]
            
            let expectedFormatValue = (format == .vc_sd_jwt) ? "vc+sd-jwt" : "dc+sd-jwt"
                        XCTAssertEqual(json?["format"] as? String, expectedFormatValue)
        }
    }


}
