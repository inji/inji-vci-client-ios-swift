import Foundation

struct IARInitialRequestBody: Codable {
    let responseType: String
    let clientId: String
    let codeChallenge: String
    let codeChallengeMethod: String
    let redirectUri: String
    let authorizationDetails: [AuthorizationDetail]
    let interactionTypesSupported: [String]

    enum CodingKeys: String, CodingKey {
        case responseType = "response_type"
        case clientId = "client_id"
        case codeChallenge = "code_challenge"
        case codeChallengeMethod = "code_challenge_method"
        case redirectUri = "redirect_uri"
        case authorizationDetails = "authorization_details"
        case interactionTypesSupported = "interaction_types_supported"
    }

    init(
        clientId: String,
        codeChallenge: String,
        redirectUri: String,
        authorizationDetails: [AuthorizationDetail],
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
}
