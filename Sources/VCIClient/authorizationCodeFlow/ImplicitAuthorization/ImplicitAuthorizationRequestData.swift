import Foundation

struct ImplicitAuthorizationRequestData: AuthorizationRequestData {
    let authorizeUrl: String
    let clientMetadata: ClientMetadata
    let pkceSession: PKCESessionManager.PKCESession
    let scope: String
    let pushedAuthorizationRequestEndpoint: String?
    let dpopJkt: String
    let tokenEndpointAuthMethodsSupported: [String]?
    let requirePushedAuthorizationRequests: Bool?

    init(
        authorizeUrl: String,
        clientMetadata: ClientMetadata,
        pkceSession: PKCESessionManager.PKCESession,
        scope: String,
        pushedAuthorizationRequestEndpoint: String? = nil,
        dpopJkt: String,
        tokenEndpointAuthMethodsSupported: [String]? = nil,
        requirePushedAuthorizationRequests: Bool? = nil
    ) {
        self.authorizeUrl = authorizeUrl
        self.clientMetadata = clientMetadata
        self.pkceSession = pkceSession
        self.scope = scope
        self.pushedAuthorizationRequestEndpoint = pushedAuthorizationRequestEndpoint
        self.dpopJkt = dpopJkt
        self.tokenEndpointAuthMethodsSupported = tokenEndpointAuthMethodsSupported
        self.requirePushedAuthorizationRequests = requirePushedAuthorizationRequests
    }
}
