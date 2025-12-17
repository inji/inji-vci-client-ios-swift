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

        let request = PresentationDuringIssuanceRequestData(
            ovpRequest: parsed.openid4vpRequest,
            authSession: parsed.authSession ?? "",
            iar: endpoint
        )

        let handler = PresentationDuringIssuanceAuthorizationMethodService(
            selectCredentialsForPresentation: selectCredentialsForPresentation,
            signVerifiablePresentation: signVerifiablePresentation
        )

        return await handler.authorizeUser(requestData: request)
    }
}

//TODO: move to separate files






