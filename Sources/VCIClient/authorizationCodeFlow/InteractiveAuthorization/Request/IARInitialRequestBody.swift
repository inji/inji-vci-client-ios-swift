import Foundation

struct IARInitialRequestBody: Codable {
    let responseType: String
    let clientId: String
    let codeChallenge: String
    let codeChallengeMethod: String
    let redirectUri: String
    let authorizationDetails: [AuthorizationDetails]
    let interactionTypesSupported: [String]
    
    //    enum CodingKeys: String, CodingKey {
    //        case responseType = "response_type"
    //        case clientId = "client_id"
    //        case codeChallenge = "code_challenge"
    //        case codeChallengeMethod = "code_challenge_method"
    //        case redirectUri = "redirect_uri"
    //        case authorizationDetails = "authorization_details"
    //        case interactionTypesSupported = "interaction_types_supported"
    //    }
    
    enum CodingKeys: String, CodingKey {
        case responseType
        case clientId
        case codeChallenge
        case codeChallengeMethod
        case redirectUri
        case authorizationDetails
        case interactionTypesSupported
    }
    
    init(
        clientId: String,
        codeChallenge: String,
        redirectUri: String,
        authorizationDetails: [AuthorizationDetails],
        interactionTypesSupported: [String],
        responseType: String = "code",
        codeChallengeMethod: String = "S256"
    ) {
        self.responseType = responseType
        self.clientId = clientId
        self.codeChallenge = codeChallenge
        self.codeChallengeMethod = codeChallengeMethod
        self.redirectUri = redirectUri
        self.authorizationDetails = authorizationDetails
        self.interactionTypesSupported = interactionTypesSupported
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(responseType, forKey: .responseType)
        try container.encode(clientId, forKey: .clientId)
        try container.encode(codeChallenge, forKey: .codeChallenge)
        try container.encode(codeChallengeMethod, forKey: .codeChallengeMethod)
        try container.encode(redirectUri, forKey: .redirectUri)
        try container.encode(authorizationDetails, forKey: .authorizationDetails)
        
        let interactionTypes = interactionTypesSupported.joined(separator: ",")
        try container.encode(interactionTypes, forKey: .interactionTypesSupported)
    }
    
    func toFormMap() -> [String: String] {
        let authDetailsJson: String = JsonUtils.encode(authorizationDetails, empty: "[]")
        
        return [
            "responseType": responseType,
            "clientId": clientId,
            "codeChallenge": codeChallenge,
            "codeChallengeMethod": codeChallengeMethod,
            "redirectUri": redirectUri,
            "authorizationDetails": authDetailsJson,
            "interactionTypeSupported": interactionTypesSupported.joined(separator: ",")
        ]
    }
    
    func toFormMapV2() -> Data {
        var params: [String: String] = [
            "response_type": "code",
            "client_id": clientId,
            "code_challenge": codeChallenge,
            "code_challenge_method": "S256",
            "redirect_uri": redirectUri,
            "interaction_types_supported":
                interactionTypesSupported.joined(separator: ",")
        ]

        params.merge(
            flattenAuthorizationDetails(authorizationDetails),
            uniquingKeysWith: { $1 }
        )

        let body = FormURLEncoder.encode(params)

        return body
    }
    
    func flattenAuthorizationDetails(
        _ details: [AuthorizationDetails]
    ) -> [String: String] {

        var params: [String: String] = [:]

        for (index, detail) in details.enumerated() {

            params["authorization_details[\(index)].type"] = detail.type
            params["authorization_details[\(index)].credential_configuration_id"] = detail.credentialConfigurationId

            
        }

        return params
    }

    
    func makeIARFormBody() throws -> Data {
        let request: IARInitialRequestBody = self
        var pairs: [(String, String)] = []
        
        func add(_ key: String, _ value: String) {
            pairs.append((key, value))
        }
        
        add("response_type", request.responseType)
        add("client_id", request.clientId)
        add("code_challenge", request.codeChallenge)
        add("code_challenge_method", request.codeChallengeMethod)
        add("redirect_uri", request.redirectUri)
        
        // authorization_details → JSON STRING inside form
        let authDetailsData = try JSONEncoder().encode(request.authorizationDetails)
        guard let authDetailsJSON = String(data: authDetailsData, encoding: .utf8) else {
            throw InteractiveAuthorizationException(
                message: "authorization_details encoding failed"
            )
        }
        add("authorization_details", authDetailsJSON)
        
        // comma-separated list
        add(
            "interaction_types_supported",
            request.interactionTypesSupported.joined(separator: ",")
        )
        
        let formString = pairs
            .map { "\($0.urlEncodedFormKey())=\($1.urlEncodedFormValue())" }
            .joined(separator: "&")
        
        return Data(formString.utf8)
    }
    
}

extension String {
    
    /// application/x-www-form-urlencoded (OAuth compliant)
    func urlEncodedFormValue() -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        
        return self
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: " ", with: "+")
        ?? self
    }
    
    func urlEncodedFormKey() -> String {
        urlEncodedFormValue()
    }
}

struct FormURLEncoder {

    static func encode(_ parameters: [String: String]) -> Data {
        let formString = parameters
            .map { key, value in
                "\(encode(key))=\(encode(value))"
            }
            .joined(separator: "&")

        return Data(formString.utf8)
    }

    private static func encode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")

        return string
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: " ", with: "+")
        ?? string
    }
}
