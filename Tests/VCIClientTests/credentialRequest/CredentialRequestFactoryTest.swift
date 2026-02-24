@testable import VCIClient
import XCTest

final class CredentialRequestFactoryTests: XCTestCase {

    private let validProof = JWTProof(jwt: "valid.jwt.string")

    func testCreateCredentialRequest_ldpvc_returnsValidRequest() throws {
        let factory = TestableCredentialRequestFactory()
        factory.credentialRequestToReturn = MockValidCredentialRequest(
            accessToken: "token",
            issuerMetaData: mockIssuerMetadata(),
            proof: validProof
        )

        let request = try factory.createCredentialRequest(
            credentialFormat: .ldp_vc,
            accessToken: "token",
            issuer: mockIssuerMetadata(),
            proofJwt: validProof
        )

        XCTAssertEqual(request.url?.absoluteString, "https://example.com")
    }

    func testCreateCredentialRequest_msomdoc_returnsValidRequest() throws {
        let factory = TestableCredentialRequestFactory()
        factory.credentialRequestToReturn = MockValidCredentialRequest(
            accessToken: "token",
            issuerMetaData: mockIssuerMetadata(),
            proof: validProof
        )

        let request = try factory.createCredentialRequest(
            credentialFormat: .mso_mdoc,
            accessToken: "token",
            issuer: mockIssuerMetadata(),
            proofJwt: validProof
        )

        XCTAssertEqual(request.url?.absoluteString, "https://example.com")
    }

    func testCreateCredentialRequest_emptyProof_throwsException() {
        let factory = TestableCredentialRequestFactory()
        let emptyProof = JWTProof(jwt: "")

        XCTAssertThrowsError(
            try factory.createCredentialRequest(
                credentialFormat: .ldp_vc,
                accessToken: "token",
                issuer: mockIssuerMetadata(),
                proofJwt: emptyProof
            )
        ) { error in
            XCTAssertTrue(error is InvalidDataProvidedException)
            XCTAssertEqual((error as? InvalidDataProvidedException)?.message, "Required details not provided : Proof object cannot be empty or invalid")
        }
    }

    func testCreateCredentialRequest_invalidValidation_throwsException() {
        let factory = TestableCredentialRequestFactory()
        factory.credentialRequestToReturn = MockInvalidCredentialRequest(
            accessToken: "token",
            issuerMetaData: mockIssuerMetadata(),
            proof: validProof
        )

        XCTAssertThrowsError(
            try factory.createCredentialRequest(
                credentialFormat: .ldp_vc,
                accessToken: "token",
                issuer: mockIssuerMetadata(),
                proofJwt: validProof
            )
        ) { error in
            XCTAssertTrue(error is InvalidDataProvidedException)
        }
    }
}
