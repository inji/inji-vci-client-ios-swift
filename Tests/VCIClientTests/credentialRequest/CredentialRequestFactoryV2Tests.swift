@testable import VCIClient
import XCTest

final class CredentialRequestFactoryV2Tests: XCTestCase {
    func testCreateCredentialRequest_includesProofsJwtArray() throws {
        let factory = CredentialRequestFactoryV2()
        let issuer = IssuerMetadata(
            credentialIssuer: "https://issuer.example.com",
            credentialEndpoint: "https://issuer.example.com/credential",
            credentialType: ["VerifiableCredential"],
            credentialFormat: .jwt_vc_json
        )

        let request = try factory.createCredentialRequest(
            credentialFormat: .jwt_vc_json,
            accessToken: "token",
            issuer: issuer,
            proofs: CredentialRequestProofs(jwt: ["proof-1"])
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer token")

        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        let proofs = try XCTUnwrap(json["proofs"] as? [String: Any])

        XCTAssertEqual(proofs["jwt"] as? [String], ["proof-1"])
        XCTAssertNil(json["proof"])
    }
}
