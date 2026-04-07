import Foundation

public struct CredentialResponse: Codable {
    public let credentials: [AnyCodable]?
    public var credentialIssuer: String?
    public var credentialConfigurationId: String?

    enum CodingKeys: String, CodingKey {
        case credentials
        case credentialIssuer = "credential_issuer"
        case credentialConfigurationId = "credential_configuration_id"
    }

    public init(
        credentials: [AnyCodable]? = nil,
        credentialIssuer: String? = nil,
        credentialConfigurationId: String? = nil
    ) {
        self.credentials = credentials
        self.credentialIssuer = credentialIssuer
        self.credentialConfigurationId = credentialConfigurationId
    }

    public func toJsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw DownloadFailedException("Failed to convert encoded response to UTF-8 string")
        }
        return jsonString
    }
}
