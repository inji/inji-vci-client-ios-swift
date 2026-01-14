import Foundation

struct AuthorizationDetails: Codable {
    let type: String
    let credentialConfigurationId: String
    let claims: [String: String]?

    enum CodingKeys: String, CodingKey {
        case type
        case credentialConfigurationId = "credential_configuration_id"
        case claims
    }

    init(type: String, credentialConfigurationId: String, claims: [String: String]? = nil) {
        self.type = type
        self.credentialConfigurationId = credentialConfigurationId
        self.claims = claims
    }
}
