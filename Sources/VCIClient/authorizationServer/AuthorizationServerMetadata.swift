import Foundation

struct AuthorizationServerMetadata: Codable {
    let issuer: String
    let grantTypesSupported: [String]?
    let tokenEndpoint: String?
    let authorizationEndpoint: String?
    let interactiveAuthorizationEndpoint: String?
    let requireInteractiveAuthorizationRequest: Bool?

    enum CodingKeys: String, CodingKey {
        case issuer
        case grantTypesSupported = "grant_types_supported"
        case tokenEndpoint = "token_endpoint"
        case authorizationEndpoint = "authorization_endpoint"
        case interactiveAuthorizationEndpoint = "interactive_authorization_endpoint"
        case requireInteractiveAuthorizationRequest = "require_interactive_authorization_request"
    }
}

