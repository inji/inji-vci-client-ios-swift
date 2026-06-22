import Foundation

struct ImplicitAuthorizationRequestData: AuthorizationRequestData {
    let authorizeUrl: String
    let clientMetadata: ClientMetadata
    let pkceSession: PKCESessionManager.PKCESession
    let scope: String
    let pushedAuthorizationRequestEndpoint: String?
    let authorizationDetails: String?
    let issuerState: String?

    init(
        authorizeUrl: String,
        clientMetadata: ClientMetadata,
        pkceSession: PKCESessionManager.PKCESession,
        scope: String,
        pushedAuthorizationRequestEndpoint: String? = nil,
        authorizationDetails: String? = nil,
        issuerState: String? = nil
    ) {
        self.authorizeUrl = authorizeUrl
        self.clientMetadata = clientMetadata
        self.pkceSession = pkceSession
        self.scope = scope
        self.pushedAuthorizationRequestEndpoint = pushedAuthorizationRequestEndpoint
        self.authorizationDetails = authorizationDetails
        self.issuerState = issuerState
    }
}
