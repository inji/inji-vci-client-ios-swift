import XCTest
@testable import VCIClient

final class CredentialOfferValidatorTests: XCTestCase {

    func testValidCredentialOfferPassesValidation() throws {
        let offer = CredentialOffer(
            credentialIssuer: "https://issuer.example.com",
            credentialConfigurationIds: ["config1"],
            grants: CredentialOfferGrants(
                preAuthorizedGrant: PreAuthCodeGrant(
                    preAuthCode: "abc123",
                    txCode: TxCode(inputMode: nil, length: 4, description: nil),
                    authorizationServer: nil,
                    interval: nil
                ),
                authorizationCodeGrant: nil
            )
        )

        XCTAssertNoThrow(try CredentialOfferValidator.validate(offer))
    }

    func testBlankCredentialIssuerThrows() {
        let offer = CredentialOffer(
            credentialIssuer: " ",
            credentialConfigurationIds: ["config1"],
            grants: nil
        )

        XCTAssertThrowsError(try CredentialOfferValidator.validate(offer))
    }

    func testNonHttpsIssuerThrows() {
        let offer = CredentialOffer(
            credentialIssuer: "http://issuer.example.com",
            credentialConfigurationIds: ["config1"],
            grants: nil
        )

        XCTAssertThrowsError(try CredentialOfferValidator.validate(offer))
    }

    func testEmptyCredentialConfigurationIdsThrows() {
        let offer = CredentialOffer(
            credentialIssuer: "https://issuer.example.com",
            credentialConfigurationIds: [],
            grants: nil
        )

        XCTAssertThrowsError(try CredentialOfferValidator.validate(offer))
    }

    func testBlankCredentialConfigurationIdThrows() {
        let offer = CredentialOffer(
            credentialIssuer: "https://issuer.example.com",
            credentialConfigurationIds: [" "],
            grants: nil
        )

        XCTAssertThrowsError(try CredentialOfferValidator.validate(offer))
    }

    func testGrantsWithoutSupportedGrantThrows() {
        let offer = CredentialOffer(
            credentialIssuer: "https://issuer.example.com",
            credentialConfigurationIds: ["config1"],
            grants: CredentialOfferGrants(
                preAuthorizedGrant: nil,
                authorizationCodeGrant: nil
            )
        )

        XCTAssertThrowsError(try CredentialOfferValidator.validate(offer))
    }

    func testBlankPreAuthorizedCodeThrows() {
        let offer = CredentialOffer(
            credentialIssuer: "https://issuer.example.com",
            credentialConfigurationIds: ["config1"],
            grants: CredentialOfferGrants(
                preAuthorizedGrant: PreAuthCodeGrant(
                    preAuthCode: " ",
                    txCode: nil,
                    authorizationServer: nil,
                    interval: nil
                ),
                authorizationCodeGrant: nil
            )
        )

        XCTAssertThrowsError(try CredentialOfferValidator.validate(offer))
    }

    func testInvalidTxCodeLengthThrows() {
        let offer = CredentialOffer(
            credentialIssuer: "https://issuer.example.com",
            credentialConfigurationIds: ["config1"],
            grants: CredentialOfferGrants(
                preAuthorizedGrant: PreAuthCodeGrant(
                    preAuthCode: "abc123",
                    txCode: TxCode(inputMode: nil, length: 0, description:nil),
                    authorizationServer: nil,
                    interval: nil
                ),
                authorizationCodeGrant: nil
            )
        )

        XCTAssertThrowsError(try CredentialOfferValidator.validate(offer))
    }
}
