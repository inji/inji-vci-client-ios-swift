import Foundation

/// Sends the credential-endpoint request with DPoP applied entirely inside the library.
///
/// When the token response carried `token_type=DPoP`, the access token is presented with the
/// `DPoP` authorization scheme alongside a signed proof. A `use_dpop_nonce` challenge is retried
/// once with the server supplied nonce. A Bearer-only challenge triggers a best-effort Bearer
/// retry per RFC 9449 section 7.2. A Bearer token response skips DPoP altogether.
class DPoPCredentialRequestSender {
    private let sendRequest: (URLRequest) async throws -> NetworkResponse

    init(sendRequest: @escaping (URLRequest) async throws -> NetworkResponse) {
        self.sendRequest = sendRequest
    }

    convenience init(session: NetworkManager = NetworkManager.shared) {
        self.init(sendRequest: { try await session.sendRequest(request: $0) })
    }

    func send(
        baseRequest: URLRequest,
        accessToken: String,
        credentialEndpoint: String,
        tokenType: String?,
        dpopManager: DPoPManager
    ) async throws -> NetworkResponse {
        let useDpop = dpopManager.isInitialized
            && tokenType?.caseInsensitiveCompare(DPoPConstants.dpopTokenType) == .orderedSame

        guard useDpop else {
            return try await sendRequest(baseRequest)
        }

        let proof = try dpopManager.generateCredentialProof(
            credentialEndpoint: credentialEndpoint,
            accessToken: accessToken
        )

        do {
            return try await sendRequest(withDpop(baseRequest, accessToken: accessToken, proof: proof))
        } catch let failure as NetworkRequestFailedException {
            guard failure.httpStatusCode == 401 else { throw failure }

            let challenge = WwwAuthenticateChallenge.parse(
                DPoPCredentialRequestSender.header(DPoPConstants.wwwAuthenticateHeader, in: failure.headers)
            )
            let nonce = DPoPCredentialRequestSender.header(DPoPConstants.dpopNonceHeader, in: failure.headers)

            if challenge.error == DPoPConstants.useDpopNonceError, let nonce = nonce {
                let retryProof = try dpopManager.generateCredentialProof(
                    credentialEndpoint: credentialEndpoint,
                    accessToken: accessToken,
                    nonce: nonce
                )
                return try await sendRequest(withDpop(baseRequest, accessToken: accessToken, proof: retryProof))
            }

            if !challenge.isDpop {
                return try await sendRequest(withBearer(baseRequest, accessToken: accessToken))
            }

            throw failure
        }
    }

    private func withDpop(_ request: URLRequest, accessToken: String, proof: String) -> URLRequest {
        var updated = request
        updated.setValue("\(DPoPConstants.dpopTokenType) \(accessToken)", forHTTPHeaderField: DPoPConstants.authorizationHeader)
        updated.setValue(proof, forHTTPHeaderField: DPoPConstants.dpopHeader)
        return updated
    }

    private func withBearer(_ request: URLRequest, accessToken: String) -> URLRequest {
        var updated = request
        updated.setValue("\(DPoPConstants.bearerTokenType) \(accessToken)", forHTTPHeaderField: DPoPConstants.authorizationHeader)
        updated.setValue(nil, forHTTPHeaderField: DPoPConstants.dpopHeader)
        return updated
    }

    private static func header(_ name: String, in headers: [AnyHashable: Any]?) -> String? {
        guard let headers = headers else { return nil }
        for (key, value) in headers {
            if let keyString = key as? String, keyString.caseInsensitiveCompare(name) == .orderedSame {
                return value as? String
            }
        }
        return nil
    }
}
