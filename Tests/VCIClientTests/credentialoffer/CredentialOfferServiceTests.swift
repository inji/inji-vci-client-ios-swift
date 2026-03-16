@testable import VCIClient
import XCTest

final class CredentialOfferServiceTests: XCTestCase {
    func test_fetchCredentialOffer_byValue_shouldParseSuccessfully() async throws {
        let mockJSON = """
        {
            "credential_issuer": "https://did:example:1234",
            "credential_configuration_ids": ["mock-cred-id"]
        }
        """
        let encoded = mockJSON.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = "openid-credential-offer://?credential_offer=\(encoded)"

        let service = CredentialOfferService()
        let offer = try await service.fetchCredentialOffer(url)

        XCTAssertEqual(offer.credentialIssuer, "https://did:example:1234")
    }

    func test_fetchCredentialOffer_byReference_shouldParseSuccessfully() async throws {
        let mockManager = MockNetworkManager()
        mockManager.responseBody =  """
        {
            "credential_issuer": "https://did:example:1234",
            "credential_configuration_ids":  ["mock-ref-id"]
        }
        """

        let uri = "openid-credential-offer://?credential_offer_uri=https://ref.example.com/offer"
        let service = CredentialOfferService(session: mockManager)
        let offer = try await service.fetchCredentialOffer(uri)

        XCTAssertEqual(offer.credentialIssuer, "https://did:example:1234")
    }

    func test_fetchCredentialOffer_withInvalidURL_shouldThrow() async {
        let service = CredentialOfferService()
        let invalid = "invalid-format"

        do {
            _ = try await service.fetchCredentialOffer(invalid)
            XCTFail("Expected OfferFetchFailedException to be thrown")
        } catch let error as CredentialOfferFetchFailedException {
            XCTAssertTrue(error.localizedDescription.contains("Invalid credential offer format"))
        } catch {
            XCTFail("Expected OfferFetchFailedException but got \(error)")
        }
    }

    

    func test_fetchCredentialOffer_emptyResponse_shouldThrow() async {
        let mockManager = MockNetworkManager()
        mockManager.responseBody = ""

        let uri = "openid-credential-offer://?credential_offer_uri=https://example.com"
        let service = CredentialOfferService(session: mockManager)

        do {
            _ = try await service.fetchCredentialOffer(uri)
            XCTFail("Expected OfferFetchFailedException to be thrown")
        } catch let error as CredentialOfferFetchFailedException {
            XCTAssertTrue(error.localizedDescription.contains("Empty response"))
        } catch {
            XCTFail("Expected OfferFetchFailedException but got \(error)")
        }
    }

    func test_fetchCredentialOffer_missingQueryParams_shouldThrow() async {
        let service = CredentialOfferService()
        let noParams = "openid-credential-offer://?"

        do {
            _ = try await service.fetchCredentialOffer(noParams)
            XCTFail("Expected OfferFetchFailedException to be thrown")
        } catch let error as CredentialOfferFetchFailedException {
            print(error.localizedDescription)
            XCTAssertTrue(error.localizedDescription.contains("Missing 'credential_offer' or 'credential_offer_uri'"))
        } catch {
            XCTFail("Expected OfferFetchFailedException but got \(error)")
        }
    }

    func test_handleByValueOffer_withBadJson_shouldThrow() async {
        let service = CredentialOfferService()
        let badJson = "%7Bbad-json%7D" // "{bad-json}" percent-encoded
        do {
            _ =  try await service.fetchCredentialOffer(badJson)
            XCTFail("Expected OfferFetchFailedException to be thrown")
        } catch let error as CredentialOfferFetchFailedException {
            XCTAssertTrue(error.localizedDescription.contains("Invalid credential offer"))
        } catch {
            XCTFail("Expected OfferFetchFailedException but got \(error)")
        }
       
    }

    func test_handleByReferenceOffer_invalidURL_shouldThrow() async {
        let service = CredentialOfferService()
        do {
            _ = try await service.fetchCredentialOffer("invalid")
            XCTFail("Expected OfferFetchFailedException to be thrown")
        } catch let error as CredentialOfferFetchFailedException {
            print("------",error.localizedDescription)
            XCTAssertTrue(error.localizedDescription.contains("Invalid credential offer"))
        } catch {
            XCTFail("Expected OfferFetchFailedException but got \(error)")
        }
    }
}
