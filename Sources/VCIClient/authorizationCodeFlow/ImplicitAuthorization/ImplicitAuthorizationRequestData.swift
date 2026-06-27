import Foundation

struct ImplicitAuthorizationRequestData: AuthorizationRequestData {
    let authorizeUrl: String
    let clientMetadata: ClientMetadata
    let pkceSession: PKCESessionManager.PKCESession
    let scope: String
    let dpopJkt: String?
}
