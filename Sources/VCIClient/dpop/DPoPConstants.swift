import Foundation

enum DPoPConstants {
    static let authorizationHeader = "Authorization"
    static let dpopHeader = "DPoP"
    static let dpopNonceHeader = "DPoP-Nonce"
    static let wwwAuthenticateHeader = "WWW-Authenticate"

    static let dpopJwtType = "dpop+jwt"
    static let dpopTokenType = "DPoP"
    static let bearerTokenType = "Bearer"

    static let useDpopNonceError = "use_dpop_nonce"

    static let httpMethodPost = "POST"
    static let proofLifetimeSeconds: TimeInterval = 60
}
