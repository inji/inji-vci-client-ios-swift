import Foundation

class AuthorizationServerDiscoveryService {
    func discover(baseUrl: String) async throws -> AuthorizationServerMetadata {
        let timeout = Constants.defaultNetworkTimeoutInMillis

        for wellKnownUrl in Self.buildCandidateWellKnownUrls(baseUrl: baseUrl) {
            do {
                let response = try await NetworkManager.shared.sendRequest(
                    url: wellKnownUrl,
                    method: .get,
                    timeoutMillis: timeout
                )

                if !response.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let metadata = try JsonUtils.deserialize(response.body, as: AuthorizationServerMetadata.self) {
                    return metadata
                }
            } catch {
                Util.logWarning(
                    message: "Discovery failed at \(wellKnownUrl), trying next candidate: \(error.localizedDescription)",
                    className: "AuthorizationServerDiscoveryService"
                )
            }
        }

        throw AuthorizationServerDiscoveryException("Failed to discover authorization server metadata at all well-known endpoints.")
    }

    /// Candidate discovery URLs in priority order.
    /// Per RFC 8414, when the issuer has a path component the well-known suffix is
    /// inserted between authority and path. The legacy OpenID Connect style
    /// (suffix appended to the issuer) is kept as a fallback.
    static func buildCandidateWellKnownUrls(baseUrl: String) -> [String] {
        let oauthSuffix = "/.well-known/oauth-authorization-server"
        let openidSuffix = "/.well-known/openid-configuration"
        var normalized = baseUrl
        while normalized.hasSuffix("/") { normalized.removeLast() }

        var candidates: [String] = []
        if let components = URLComponents(string: normalized),
           let scheme = components.scheme,
           let host = components.host {
            var path = components.path
            while path.hasSuffix("/") { path.removeLast() }
            if !path.isEmpty {
                let port = components.port.map { ":\($0)" } ?? ""
                let authority = "\(scheme)://\(host)\(port)"
                candidates.append("\(authority)\(oauthSuffix)\(path)")
                candidates.append("\(authority)\(openidSuffix)\(path)")
            }
        }
        candidates.append("\(normalized)\(oauthSuffix)")
        candidates.append("\(normalized)\(openidSuffix)")
        return candidates
    }
}
