import Foundation

struct OpenId4VpPresentationResponse: Decodable {

    let status: String
    let type: String
    let authSession: String
    let openid4vpRequest: [String: Any]

    // CodingKeys to map snake_case keys
    private enum CodingKeys: String, CodingKey {
        case status
        case type
        case authSession = "auth_session"
        case openid4vpRequest = "openid4vp_request"
    }

    init(json: [String: Any]) throws {
        guard let status = json["status"] as? String else {
            throw ValidationError.missing("status")
        }
        guard let type = json["type"] as? String else {
            throw ValidationError.missing("type")
        }
        guard let authSession = json["auth_session"] as? String else {
            throw ValidationError.missing("auth_session")
        }
        guard let request = json["openid4vp_request"] as? [String: Any] else {
            throw ValidationError.missing("openid4vp_request")
        }

        self.status = status
        self.type = type
        self.authSession = authSession
        self.openid4vpRequest = request
    }
    
    // Custom Decodable init to keep [String: Any] without changing field type
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(String.self, forKey: .status)
        self.type = try container.decode(String.self, forKey: .type)
        self.authSession = try container.decode(String.self, forKey: .authSession)

        // Decode openid4vp_request as raw JSON and convert to [String: Any]
        // 1) Decode it as a generic JSON object using an intermediate Data approach
        // We create a nested decoder for the key and re-encode to Data, then JSONSerialization to [String: Any].
        // Since Swift’s Decodable cannot decode Any directly, this is a pragmatic bridge.
        if let nestedDecoder = try? container.superDecoder(forKey: .openid4vpRequest) {
            // Attempt to decode an arbitrary JSON structure into Foundation objects
            let any = try OpenId4VpPresentationResponse.decodeAny(from: nestedDecoder)
            guard let dict = any as? [String: Any] else {
                throw ValidationError.invalid("openid4vp_request")
            }
            self.openid4vpRequest = dict
        } else {
            // Fallback: try decoding as Data via a single-value container
            // (This path is unlikely with a keyed container, but kept for resilience)
            let data = try container.decode(Data.self, forKey: .openid4vpRequest)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = obj as? [String: Any] else {
                throw ValidationError.invalid("openid4vp_request")
            }
            self.openid4vpRequest = dict
        }
    }

    // Helper to decode arbitrary JSON into Foundation types
    private static func decodeAny(from decoder: Decoder) throws -> Any {
        if var arrayContainer = try? decoder.unkeyedContainer() {
            var arr: [Any] = []
            while !arrayContainer.isAtEnd {
                let valueDecoder = try arrayContainer.superDecoder()
                let value = try decodeAny(from: valueDecoder)
                arr.append(value)
            }
            return arr
        }
        if let container = try? decoder.container(keyedBy: DynamicCodingKeys.self) {
            var dict: [String: Any] = [:]
            for key in container.allKeys {
                let valueDecoder = try container.superDecoder(forKey: key)
                dict[key.stringValue] = try decodeAny(from: valueDecoder)
            }
            return dict
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { return NSNull() }
        if let b = try? single.decode(Bool.self) { return b }
        if let i = try? single.decode(Int.self) { return i }
        if let d = try? single.decode(Double.self) { return d }
        if let s = try? single.decode(String.self) { return s }
        // As a last resort, try Data then JSON parse
        if let data = try? single.decode(Data.self),
           let obj = try? JSONSerialization.jsonObject(with: data, options: []) {
            return obj
        }
        throw ValidationError.invalid("Unsupported JSON value")
    }

    // CodingKey that can be created from any string key at runtime
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }
    
    //TODO : validation of iar request content requried?
}

extension OpenId4VpPresentationResponse {

    func validate() throws {
        guard status == "require_interaction" else {
            throw ValidationError.invalidStatus(status)
        }

        guard type == "openid4vp_presentation" else {
            throw ValidationError.invalidType(type)
        }

        guard !authSession.isEmpty else {
            throw ValidationError.blankAuthSession
        }

        guard !openid4vpRequest.isEmpty else {
            throw ValidationError.emptyOpenId4VpRequest
        }

        if openid4vpRequest.keys.contains("request") {
            try validateSignedRequest()
        } else {
            try validateUnsignedRequest()
        }
    }

    private func validateUnsignedRequest() throws {
        //TODO: remove this - OVP lib does it not needed
        guard let responseType = openid4vpRequest["response_type"] as? String else {
            throw ValidationError.missing("response_type")
        }
        guard responseType == "vp_token" else {
            throw ValidationError.invalid("response_type")
        }

        guard let responseMode = openid4vpRequest["response_mode"] as? String else {
            throw ValidationError.missing("response_mode")
        }
        guard responseMode == "iar_post" || responseMode == "iar_post.jwt" else {
            throw ValidationError.invalid("response_mode")
        }

        guard let nonce = openid4vpRequest["nonce"] as? String else {
            throw ValidationError.missing("nonce")
        }
        guard !nonce.isEmpty else {
            throw ValidationError.blank("nonce")
        }
    }

    private func validateSignedRequest() throws {
        guard let jwt = openid4vpRequest["request"] as? String else {
            throw ValidationError.missing("request")
        }

        let claims = try decodeJwtPayload(jwt: jwt)

        // TODO: remove this not needed
        guard let aud = claims["aud"] as? String else {
            throw ValidationError.missing("aud")
        }
        guard aud.hasPrefix("iar:") else {
            throw ValidationError.invalid("aud")
        }

        guard let expectedOrigins = claims["expected_origins"] as? [String],
              expectedOrigins.count == 1 else {
            throw ValidationError.invalid("expected_origins")
        }
    }
}

extension OpenId4VpPresentationResponse {

    func decodeJwtPayload(jwt: String) throws -> [String: Any] {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { throw ValidationError.malformedJwt }

        // Base64 decode
        let payloadString = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
//            .padding(toLength: ((payloadString.count + 3) / 4) * 4, withPad: "=", startingAt: 0)

        guard let data = Data(base64Encoded: payloadString) else {
            throw ValidationError.malformedJwt
        }

        let json = try JSONSerialization.jsonObject(with: data, options: [])

        guard let dict = json as? [String: Any] else {
            throw ValidationError.invalid("jwt payload")
        }

        return dict
    }
}




enum ValidationError: Error {
    case invalidStatus(String)
    case invalidType(String)
    case blankAuthSession
    case emptyOpenId4VpRequest
    case missing(String)
    case invalid(String)
    case blank(String)
    case malformedJwt
}
