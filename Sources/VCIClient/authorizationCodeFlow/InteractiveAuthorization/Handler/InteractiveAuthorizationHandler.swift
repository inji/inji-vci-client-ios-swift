import Foundation

final class InteractiveAuthorizationHandler {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    func handle(
        endpoint: String,
        clientMetadata: ClientMetadata,
        credentialConfigurationId: String,
        authorizationMethods: [AuthorizationMethod],
        pkceSession: PKCESessionManager.PKCESession,
        timeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> AuthorizationResponse {
        
        do {
            // interaction types supported will be populated from the authorization methods once redirect_to_web interaction is supported
            let interactionTypesSupported = authorizationMethods.compactMap { method in
                let type = method.type.rawValue
                return type != InteractionType.redirectToWeb.rawValue ? type : nil
            }
            
            if(interactionTypesSupported.isEmpty) {
                throw InteractiveAuthorizationException(
                    message: "No supported interaction types found in authorization methods"
                )
            }
            
            let initialIarRequest =  buildInitialIarRequest(
                clientMetadata: clientMetadata,
                credentialConfigurationId: credentialConfigurationId,
                pkce: pkceSession,
                interactionTypesSupported: interactionTypesSupported
            )
            
            let interactiveAuthorizationResponse = try await self.networkManager.sendRequest(
                url: endpoint,
                method: .post,
                headers: [Header.contentType.rawValue: ContentTypes.applicationFormUrlEncoded.rawValue],
                bodyParams: initialIarRequest,
//                body: initialIarRequest,
                timeoutMillis: timeoutInMillis
            )
            
            let type: String = try extractTypeAndThrowIfError(interactiveAuthorizationResponse.body)
            
            switch type {
            case InteractionType.openId4VpPresentation.rawValue:
                return try await handlePresentationInteraction(
                    presentationInteractionResponse: interactiveAuthorizationResponse.body,
                    authorizationMethods: authorizationMethods,
                    endpoint: endpoint,
                    timeoutInMillis: timeoutInMillis
                )
                
            default:
                throw InteractiveAuthorizationException(
                    message: "Unsupported interaction type: \(type)"
                )
            }
            
        } catch let e as InteractiveAuthorizationException {
            print("Interactive authorization failed: \(e.message)")
            throw e
        } catch {
            print("Interactive authorization failed: \(error.localizedDescription)")
            throw InteractiveAuthorizationException(
                message: "Interactive authorization failed: \(error.localizedDescription)"
            )
        }
    }
    
    private func buildInitialIarRequestV2(
        clientMetadata: ClientMetadata,
        credentialConfigurationId: String,
        pkce: PKCESessionManager.PKCESession,
        interactionTypesSupported: [String]
    ) throws -> Data {
        
        let details = [
            AuthorizationDetails(
                type: "openid_credential",
                credentialConfigurationId: credentialConfigurationId
            )
        ]
        
        let iarRequest = IARInitialRequestBody(
            clientId: clientMetadata.clientId,
            codeChallenge: pkce.codeChallenge,
            redirectUri: clientMetadata.redirectUri,
            authorizationDetails: details,
            interactionTypesSupported: interactionTypesSupported
        )
        
        do {
            let jsonData = try JSONEncoder().encode(iarRequest)
            return jsonData
        } catch {
            throw InteractiveAuthorizationException(message: "Error in constructing request")
        }
    }
    
    private func buildInitialIarRequestV3(
        clientMetadata: ClientMetadata,
        credentialConfigurationId: String,
        pkce: PKCESessionManager.PKCESession,
        interactionTypesSupported: [String]
    ) throws -> Data {
        
        let details = [
            AuthorizationDetails(
                type: "openid_credential",
                credentialConfigurationId: credentialConfigurationId
            )
        ]
        
        let iarRequest = IARInitialRequestBody(
            clientId: clientMetadata.clientId,
            codeChallenge: pkce.codeChallenge,
            redirectUri: clientMetadata.redirectUri,
            authorizationDetails: details,
            interactionTypesSupported: interactionTypesSupported
        )
        
        return try iarRequest.makeIARFormBody()
    }
    
    private func buildInitialIarRequest(
        clientMetadata: ClientMetadata,
        credentialConfigurationId: String,
        pkce: PKCESessionManager.PKCESession,
        interactionTypesSupported: [String]
    ) -> [String: String] {
        
        let details = [
            AuthorizationDetails(
                type: "openid_credential",
                credentialConfigurationId: credentialConfigurationId
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

    private func extractTypeAndThrowIfError(_ responseBody: String) throws -> String {
        let json = JsonUtils.toMap(responseBody)
        
        if let type = json["type"] as? String {
            return type
        }
        
        if let error = json["error"] as? String {
            let errorDescription = (json["error_description"] as? String) ?? ""
            var message = "authorization server error: \(error)"
            if !errorDescription.isEmpty {
                message += " - \(errorDescription)"
            }
            throw InteractiveAuthorizationException(message: message)
        } else {
            throw InteractiveAuthorizationException(message: "Missing 'type' in interaction response from authorization server")
        }
    }
    
    private func handlePresentationInteraction(
        presentationInteractionResponse: String,
        authorizationMethods: [AuthorizationMethod],
        endpoint: String,
        timeoutInMillis: Int64
    ) async throws -> AuthorizationResponse {
        
        guard let parsedPresentationInteractionResponse = try? JsonUtils.deserialize(presentationInteractionResponse, as: PresentationInteractionResponse.self) else {
            throw InteractiveAuthorizationException(message: "Failed to parse presentation interaction response")
        }
        
        do {
            try parsedPresentationInteractionResponse.validate()
        } catch {
            throw InteractiveAuthorizationException(  message: "Invalid presentation interaction response: \(error.localizedDescription)")
        }
        
        guard
            case let .presentationDuringIssuance(selectCredentialsForPresentation, signVerifiablePresentation) = authorizationMethods.first(where: { $0.type == .openId4VpPresentation })
        else {
            throw InteractiveAuthorizationException(message: "Presentation callback missing")
        }
        
        let authorizationService = PresentationDuringIssuanceAuthorizationMethodService(
            selectCredentialsForPresentation: selectCredentialsForPresentation,
            signVerifiablePresentation: signVerifiablePresentation,
            networkManager: self.networkManager
        )
        
        return try await authorizationService.authorizeUser(
            requestData: PresentationDuringIssuanceRequestData(
                ovpRequest: parsedPresentationInteractionResponse.openid4vpRequest,
                authSession: parsedPresentationInteractionResponse.authSession ?? "",
                iar: endpoint
            ),
            networkTimeout: timeoutInMillis
        )
    }
}







