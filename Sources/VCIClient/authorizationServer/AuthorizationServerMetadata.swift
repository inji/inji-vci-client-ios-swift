import Foundation

struct AuthorizationServerMetadata: Codable {
    let issuer: String
    let grantTypesSupported: [String]?
    let tokenEndpoint: String?
    let authorizationEndpoint: String?
    let interactiveAuthorizationEndpoint: String?
    let requireInteractiveAuthorizationRequest: Bool?
    let pushedAuthorizationRequestEndpoint: String?
    let dpopSigningAlgValuesSupported: [String]?

    enum CodingKeys: String, CodingKey {
        case issuer
        case grantTypesSupported = "grant_types_supported"
        case tokenEndpoint = "token_endpoint"
        case authorizationEndpoint = "authorization_endpoint"
        case interactiveAuthorizationEndpoint = "interactive_authorization_endpoint"
        case requireInteractiveAuthorizationRequest = "require_interactive_authorization_request"
        case pushedAuthorizationRequestEndpoint = "pushed_authorization_request_endpoint"
        case dpopSigningAlgValuesSupported = "dpop_signing_alg_values_supported"
    }

    init(
        issuer: String,
        grantTypesSupported: [String]?,
        tokenEndpoint: String?,
        authorizationEndpoint: String?,
        interactiveAuthorizationEndpoint: String?,
        requireInteractiveAuthorizationRequest: Bool? = nil,
        pushedAuthorizationRequestEndpoint: String? = nil,
        dpopSigningAlgValuesSupported: [String]? = nil
    ) {
        self.issuer = issuer
        self.grantTypesSupported = grantTypesSupported
        self.tokenEndpoint = tokenEndpoint
        self.authorizationEndpoint = authorizationEndpoint
        self.interactiveAuthorizationEndpoint = interactiveAuthorizationEndpoint
        self.requireInteractiveAuthorizationRequest = requireInteractiveAuthorizationRequest
        self.pushedAuthorizationRequestEndpoint = pushedAuthorizationRequestEndpoint
        self.dpopSigningAlgValuesSupported = dpopSigningAlgValuesSupported
    }
}
