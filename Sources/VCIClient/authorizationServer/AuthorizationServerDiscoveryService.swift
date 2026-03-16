import Foundation

class AuthorizationServerDiscoveryService {
    func discover(baseUrl: String) async throws -> AuthorizationServerMetadata {
        let oauthUrl = "\(baseUrl)/.well-known/oauth-authorization-server"
        let openidUrl = "\(baseUrl)/.well-known/openid-configuration"
        let timeout = Constants.defaultNetworkTimeoutInMillis

        do {
            let oauthResponse = try await NetworkManager.shared.sendRequest(
                url: oauthUrl,
                method: .get,
                timeoutMillis: timeout
            )

            if !oauthResponse.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let metadata = try JsonUtils.deserialize(oauthResponse.body, as: AuthorizationServerMetadata.self) {
                return metadata
            }
        } catch {
            Util.logWarning(
                message: "OAuth discovery failed, trying OpenID discovery: \(error.localizedDescription)",
                className: "AuthorizationServerDiscoveryService"
            )
        }

        do {
            let openidResponse = try await NetworkManager.shared.sendRequest(
                url: openidUrl,
                method: .get,
                timeoutMillis: timeout
            )

            if openidResponse.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
               let metadata = try JsonUtils.deserialize(openidResponse.body, as: AuthorizationServerMetadata.self) {
                return metadata
            }

        } catch {
            Util.logWarning(
                message: "OpenID discovery also failed: \(error.localizedDescription)",
                className: "AuthorizationServerDiscoveryService"
            )
        }

        throw AutorizationServerDiscoveryException("Failed to discover authorization server metadata at both endpoints.")
    }
}
