final class RedirectToWebAuthorizationMethodService: AuthorizationMethodService {

    private let openWebPage: OpenWebPageCallback

    init(openWebPage: @escaping OpenWebPageCallback) {
        self.openWebPage = openWebPage
    }

    func type() -> String {
        return InteractionType.redirectToWeb.rawValue
    }

    func authorizeUser(
        requestData: AuthorizationRequestData,
        networkTimeout: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> AuthorizationResponse {

        guard let request = requestData as? ImplicitAuthorizationRequestData else {
            throw IllegalArgumentException(
                "RedirectToWebAuthorizationHandler expects ImplicitAuthorizationRequestData but received \(Swift.type(of: requestData))"
            )
        }

        let authUrl = AuthorizationUrlBuilder.build(
            baseUrl: request.authorizeUrl,
            clientId: request.clientMetadata.clientId,
            redirectUri: request.clientMetadata.redirectUri,
            scope: request.scope,
            state: request.pkceSession.state,
            codeChallenge: request.pkceSession.codeChallenge,
            nonce: request.pkceSession.nonce
        )

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

