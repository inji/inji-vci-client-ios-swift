final class RedirectToWebAuthorizationMethodService: AuthorizationMethodService {

    private let openWebPage: OpenWebPageCallback
    private let parService: PushedAuthorizationRequestService

    init(
        openWebPage: @escaping OpenWebPageCallback,
        parService: PushedAuthorizationRequestService = PushedAuthorizationRequestService()
    ) {
        self.openWebPage = openWebPage
        self.parService = parService
    }

    func type() -> String {
        return InteractionType.redirectToWeb.rawValue
    }

    func authorizeUser(
        requestData: AuthorizationRequestData
    ) async throws -> AuthorizationResponse {

        guard let request = requestData as? ImplicitAuthorizationRequestData else {
            throw InteractiveAuthorizationException(
                message: "RedirectToWebAuthorizationMethodService expects ImplicitAuthorizationRequestData but received \(Swift.type(of: requestData))"
            )
        }

        let authUrl: String
        if let parEndpoint = request.pushedAuthorizationRequestEndpoint, !parEndpoint.isEmpty {
            let parResponse = try await parService.pushAuthorizationRequest(
                parEndpoint: parEndpoint,
                clientId: request.clientMetadata.clientId,
                redirectUri: request.clientMetadata.redirectUri,
                codeChallenge: request.pkceSession.codeChallenge,
                state: request.pkceSession.state,
                nonce: request.pkceSession.nonce,
                scope: request.scope,
                authorizationDetails: request.authorizationDetails,
                issuerState: request.issuerState
            )
            authUrl = AuthorizationUrlBuilder.buildWithRequestUri(
                baseUrl: request.authorizeUrl,
                clientId: request.clientMetadata.clientId,
                requestUri: parResponse.requestUri
            )
        } else {
            authUrl = AuthorizationUrlBuilder.build(
                baseUrl: request.authorizeUrl,
                clientId: request.clientMetadata.clientId,
                redirectUri: request.clientMetadata.redirectUri,
                scope: request.scope,
                state: request.pkceSession.state,
                codeChallenge: request.pkceSession.codeChallenge,
                nonce: request.pkceSession.nonce
            )
        }

        let authorizationResponse = try await openWebPage(authUrl)

        if authorizationResponse["error"] != nil {
            return AuthorizationResponse(
                authorizationCode: nil,
                status: "error",
                error: authorizationResponse["error"] as? String,
                errorDescription: authorizationResponse["error_description"] as? String,
                authSession: nil
            )
        }

        guard let code = authorizationResponse["code"] as? String else {
            throw InteractiveAuthorizationException(
                message: "Missing code (authorization code) in successful redirect response"
            )
        }

        return AuthorizationResponse(
            authorizationCode: code,
            status: "success",
            error: nil,
            errorDescription: nil,
            authSession: authorizationResponse["auth_session"] as? String
        )
    }
}

