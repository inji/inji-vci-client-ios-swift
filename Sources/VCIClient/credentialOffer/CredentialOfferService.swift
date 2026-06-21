import Foundation

class CredentialOfferService {
    private let session: NetworkManager

    init(session: NetworkManager = NetworkManager.shared) {
        self.session = session
    }

    func fetchCredentialOffer(_ credentialOfferData: String) async throws -> CredentialOffer {
        do {
            let normalized = credentialOfferData
                .replacingOccurrences(of: "openid-credential-offer://?", with: "openid-credential-offer://dummy?")

            guard let url = URL(string: normalized),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                throw CredentialOfferFetchFailedException("Invalid credential offer format")
            }

            var queryParams: [String: String] = [:]

            for item in queryItems {
                guard queryParams[item.name] == nil else {
                    throw CredentialOfferFetchFailedException("Duplicate query parameter: \(item.name)")
                }

                queryParams[item.name] = item.value ?? ""
            }

            if let encoded = queryParams["credential_offer"] {
                return try handleByValueOffer(encodedOffer: encoded)
            } else if let uri = queryParams["credential_offer_uri"] {
                return try await handleByReferenceOffer(url: uri)
            } else {
                throw CredentialOfferFetchFailedException(
                    "Invalid credential offer URL: Missing 'credential_offer' or 'credential_offer_uri'"
                )
            }

        } catch let e as CredentialOfferFetchFailedException {
            throw e
        } catch let e as VCIClientException {
            throw CredentialOfferFetchFailedException(
                e.message,
                issuerErrorCode: e.issuerErrorCode,
                issuerErrorDescription: e.issuerErrorDescription,
                cause: e
            )

        } catch {
            throw CredentialOfferFetchFailedException(
                error.localizedDescription,
                cause: error
            )
        }
    }

    func handleByValueOffer(encodedOffer: String) throws -> CredentialOffer {
        guard let decoded = encodedOffer.removingPercentEncoding else {
            throw CredentialOfferFetchFailedException("Invalid credential offer JSON")
        }

        return try parseCredentialOffer(json: decoded)
    }

    func handleByReferenceOffer(url: String) async throws -> CredentialOffer {
        guard let requestURL = URL(string: url),
              requestURL.scheme != nil,
              requestURL.host != nil else {
            throw CredentialOfferFetchFailedException("Invalid credential_offer_uri")
        }

        let response = try await session.sendRequest(
            url: url,
            method: .get,
            headers: ["Accept": "application/json"]
        )

        guard !response.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CredentialOfferFetchFailedException("Empty response from \(url)")
        }

        return try parseCredentialOffer(json: response.body)
    }

    private func parseCredentialOffer(json: String) throws -> CredentialOffer {
        do {
            guard let data = json.data(using: .utf8) else {
                throw CredentialOfferFetchFailedException("Invalid credential offer JSON")
            }

            let decoder = JSONDecoder()
            let offer = try decoder.decode(CredentialOffer.self, from: data)
            try CredentialOfferValidator.validate(offer)
            return offer

        } catch let e as CredentialOfferFetchFailedException {
            throw e

        } catch {
            throw CredentialOfferFetchFailedException(
                "Invalid credential offer JSON",
                cause: error
            )
        }
    }
}
