import Foundation

public struct CredentialResponseDraft13: Codable {
    public let credential: AnyCodable
    public var credentialIssuer: String?
    public var credentialConfigurationId: String?

    enum CodingKeys: String, CodingKey {
        case credential
        case credentialIssuer
        case credentialConfigurationId
    }

    public init(
        credential: AnyCodable,
        credentialIssuer: String? = nil,
        credentialConfigurationId: String? = nil
    ) {
        self.credential = credential
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


public struct AnyCodable: Codable {
    var value: Any

    init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let nestedDict = try? container.decode([String: AnyCodable].self) {
            value = nestedDict.mapValues { $0.value }
        } else if let nestedArray = try? container.decode([AnyCodable].self) {
            value = nestedArray.map { $0.value }
        } else if container.decodeNil() {
            value = Optional<Any>.none as Any
        } else {
            Util.logError(message: "Error occurred while decoding response", className: String(describing: type(of: self)))
            throw DownloadFailedException("Failed to decode credential response: unsupported value type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let nestedDict = value as? [String: Any] {
            try container.encode(nestedDict.mapValues { AnyCodable($0) })
        } else if let nestedArray = value as? [Any] {
            try container.encode(nestedArray.map { AnyCodable($0) })
        } else if value is Optional<Any> {
            try container.encodeNil()
        } else {
            Util.logError(message: "Error occurred while encoding response", className: String(describing: type(of: self)))
            throw DownloadFailedException("Failed to encode credential response: unsupported value type")
        }
    }
}
