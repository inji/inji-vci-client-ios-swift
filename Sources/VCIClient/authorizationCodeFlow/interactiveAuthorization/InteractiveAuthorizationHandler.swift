import Foundation

final class InteractiveAuthorizationHandler {

    func handle(
        endpoint: String,
        clientMetadata: ClientMetadata,
        credentialConfigurationId: String,
        authorizationMethods: [AuthorizationMethod],
        pkceSession: PKCESessionManager.PKCESession,
        networkSession: NetworkManager = NetworkManager.shared
    ) async throws -> AuthorizationResponse {

        do {
            let interactionTypesSupported =
                authorizationMethods.map { $0.type.rawValue }

            let requestMap = buildIarRequest(
                clientMetadata: clientMetadata,
                credentialConfigId: credentialConfigurationId,
                pkce: pkceSession,
                interactionTypesSupported: interactionTypesSupported
            )

            let response = try await networkSession.sendRequest(
                url: endpoint,
                method: .post,
                headers: ["Content-Type": "application/x-www-form-urlencoded"], bodyParams: requestMap
            )

            let type: String
            do {
                type = try extractInteractionType(response.body)
            } catch {
                throw InteractiveAuthorizationException(
                    message: "Failed to parse and extract interaction type: \(error.localizedDescription)"
                )
            }

            switch type {
            case InteractionType.openId4VpPresentation.rawValue:
                return try await handlePresentationInteraction(
                    responseBody: response.body,
                    authorizationMethods: authorizationMethods,
                    endpoint: endpoint
                )

            default:
                throw InteractiveAuthorizationException(
                    message: "Unsupported interaction type: \(type)"
                )
            }

        } catch let e as InteractiveAuthorizationException {
            print("IAR Error: \(e.message)")
            throw e
        } catch {
            print("IAR Fatal Error: \(error.localizedDescription)")
            throw InteractiveAuthorizationException(
                message: "Interactive authorization failed: \(error.localizedDescription)"
            )
        }
    }

    private func buildIarRequest(
        clientMetadata: ClientMetadata,
        credentialConfigId: String,
        pkce: PKCESessionManager.PKCESession,
        interactionTypesSupported: [String]
    ) -> [String: String] {

        let details = [
            AuthorizationDetail(
                type: "openid_credential",
                credentialConfigurationId: [credentialConfigId]
            )
        ]

        return IARInitialRequestBody(
            clientId: clientMetadata.clientId,
            codeChallenge: pkce.codeChallenge,
            redirectUri: clientMetadata.redirectUri,
            authorizationDetails: details,
            interactionTypesSupported: interactionTypesSupported
        ).toFormMap()
    }

    private func extractInteractionType(_ responseBody: String) throws -> String {
        guard
            let data = responseBody.data(using: .utf8),
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw InteractiveAuthorizationException(message: "Invalid JSON response")
        }

        return json["type"] as? String ?? ""
    }

    private func handlePresentationInteraction(
        responseBody: String,
        authorizationMethods: [AuthorizationMethod],
        endpoint: String
    ) async throws -> AuthorizationResponse {
            
        guard let parsed = try JsonUtils.deserialize(responseBody, as: OpenId4VpPresentationResponse.self) else {
            throw InteractiveAuthorizationException(message: "Failed to parse OpenID4VP response")
        }

        do {
            try parsed.validate()
        } catch {
            throw InteractiveAuthorizationException(  message: "Invalid OpenID4VP response: \(error.localizedDescription)"            )
        }
        
        guard
            case let .presentationDuringIssuance(selectCredentialsForPresentation, signVerifiablePresentation) = authorizationMethods.first(where: { $0.type == .openId4VpPresentation })
        else {
            throw InteractiveAuthorizationException(message: "Presentation callback missing")
        }

        let request = PresentationAuthorizationRequestData(
            ovpRequest: parsed.openid4vpRequest,
            authSession: parsed.authSession,
            iar: endpoint
        )

        let handler = PresentationDuringIssuanceHandler(
            selectCredentialsForPresentation: selectCredentialsForPresentation,
            signVerifiablePresentation: signVerifiablePresentation
        )

        return await handler.authorizeUser(requestData: request)
    }
}

//TODO: move to separate files

struct AuthorizationDetail: Codable {
    let type: String
    let credentialConfigurationId: [String]
    let claims: [String: String]?

    enum CodingKeys: String, CodingKey {
        case type
        case credentialConfigurationId = "credential_configuration_id"
        case claims
    }

    init(type: String, credentialConfigurationId: [String], claims: [String: String]? = nil) {
        self.type = type
        self.credentialConfigurationId = credentialConfigurationId
        self.claims = claims
    }
}



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
        let authDetailsJson: String
        if let data = try? JSONEncoder().encode(authorizationDetails),
           let jsonString = String(data: data, encoding: .utf8) {
            authDetailsJson = jsonString
        } else {
            authDetailsJson = "[]"
        }

        return [
            "response_type": responseType,
            "client_id": clientId,
            "code_challenge": codeChallenge,
            "code_challenge_method": codeChallengeMethod,
            "redirect_uri": redirectUri,
            "authorization_details": authDetailsJson,
            "interaction_types_supported": interactionTypesSupported.joined(separator: ",")
        ]
    }
}
