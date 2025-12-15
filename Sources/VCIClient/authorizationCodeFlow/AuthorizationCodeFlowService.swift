import Foundation

class AuthorizationCodeFlowService {
    private let authServerResolver: AuthorizationServerResolver
    private let tokenService: TokenService
    private let credentialRequestExecutor: CredentialRequestExecutor
    private let pkceSessionManager: PKCESessionManager
    private let interactiveAuthorizationHandler: InteractiveAuthorizationHandler
    
    init(
        authServerResolver: AuthorizationServerResolver = AuthorizationServerResolver(),
        tokenService: TokenService = TokenService(),
        credentialExecutor: CredentialRequestExecutor = CredentialRequestExecutor(),
        pkceSessionManager: PKCESessionManager = PKCESessionManager()
    ) {
        self.authServerResolver = authServerResolver
        self.tokenService = tokenService
        self.credentialRequestExecutor = credentialExecutor
        self.pkceSessionManager = pkceSessionManager
        self.interactiveAuthorizationHandler = InteractiveAuthorizationHandler()
    }
    
    func requestCredentials(
        issuerMetadata: IssuerMetadata,
        clientMetadata: ClientMetadata,
        authorizationMethods: [AuthorizationMethod] = [],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        credentialOffer: CredentialOffer? = nil,
        downloadTimeOutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis,
        session: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponse {
        do {
            let pkceSession = pkceSessionManager.createSession()
            
            let authServerMetadata: AuthorizationServerMetadata
            do {
                authServerMetadata = try await authServerResolver.resolveForAuthCode(
                    issuerMetadata: issuerMetadata,
                    credentialOffer: credentialOffer
                )
            } catch {
                throw DownloadFailedException("Failed to resolve authorization server metadata for issuer \(issuerMetadata.credentialIssuer): \(error.localizedDescription)")
            }
            
            let token: TokenResponse
            do {
                token = try await performAuthorizationAndGetToken(
                    authServerMetadata: authServerMetadata,
                    issuerMetadata: issuerMetadata,
                    clientMetadata: clientMetadata,
                    authorizationMethods: authorizationMethods,
                    pkceSession: pkceSession,
                    getTokenResponse: getTokenResponse,
                    credentialConfigurationId: credentialConfigurationId
                )
            } catch {
                throw DownloadFailedException("Failed to obtain access token via authorization code flow: \(error.localizedDescription)")
            }
            
            let jwt: String
            do {
                jwt  = try await getProofJwt(
                    issuerMetadata.credentialIssuer,
                    token.cNonce,
                    proofSigningAlgorithmsSupportedSupported
                )
            } catch {
                throw DownloadFailedException("Failed to obtain proof JWT from callback: \(error.localizedDescription)")
            }
            
            let proof = JWTProof(jwt: jwt)
            
            guard let response = try await credentialRequestExecutor.requestCredential(
                issuerMetadata: issuerMetadata, credentialConfigurationId: credentialConfigurationId,
                proof: proof,
                accessToken: token.accessToken,
                timeoutInMillis: downloadTimeOutInMillis,
                session: session
            ) else {
                throw DownloadFailedException("Credential request returned nil.")
            }
            
            return response
            
        } catch {
            throw DownloadFailedException("Download failed via authorization code flow: \(error.localizedDescription)")
        }
    }
    
    private func performAuthorizationAndGetToken(
        authServerMetadata: AuthorizationServerMetadata,
        issuerMetadata: IssuerMetadata,
        clientMetadata: ClientMetadata,
        authorizationMethods: [AuthorizationMethod],
        pkceSession: PKCESessionManager.PKCESession,
        getTokenResponse: @escaping TokenResponseCallback,
        credentialConfigurationId : String
    ) async throws -> TokenResponse {
        guard let tokenEndpoint = issuerMetadata.tokenEndpoint ?? authServerMetadata.tokenEndpoint else {
            throw DownloadFailedException("Missing token endpoint for issuer \(issuerMetadata.credentialIssuer)")
        }

        let authCode = try await obtainAuthorizationCode(authorizationServerMetadata: authServerMetadata, issuerMetadata: issuerMetadata, clientMetadata: clientMetadata, pkceSession: pkceSession, credentialConfigurationId: credentialConfigurationId, authorizationMethods: authorizationMethods)
        
        return try await tokenService.getAccessToken(
            getTokenResponse: getTokenResponse,
            tokenEndpoint: tokenEndpoint,
            authCode: authCode,
            clientId: clientMetadata.clientId,
            redirectUri: clientMetadata.redirectUri,
            codeVerifier: pkceSession.codeVerifier
        )
    }
    
    private func obtainAuthorizationCode(
        authorizationServerMetadata: AuthorizationServerMetadata,
        issuerMetadata: IssuerMetadata,
        clientMetadata: ClientMetadata,
        pkceSession: PKCESessionManager.PKCESession,
        credentialConfigurationId: String,
        authorizationMethods: [AuthorizationMethod]
    ) async throws -> String {
        
        let interactiveEndpoint = authorizationServerMetadata.interactiveAuthorizationEndpoint
        
        let hasInteractiveAuthorizationMethods = !(authorizationMethods.isEmpty)
        
        if let interactiveEndpoint,
           hasInteractiveAuthorizationMethods {
            
            return try await obtainAuthorizationCodeViaInteractiveEndpoint(
                endpoint: interactiveEndpoint,
                issuerMetadata: issuerMetadata,
                clientMetadata: clientMetadata,
                pkceSession: pkceSession,
                credentialConfigurationId: credentialConfigurationId,
                authorizationMethods: authorizationMethods
            )
            
        } else {
            
            return try await obtainAuthorizationCodeViaStandardRedirectToWeb(
                authorizationServerMetadata: authorizationServerMetadata,
                issuerMetadata: issuerMetadata,
                clientMetadata: clientMetadata,
                pkceSession: pkceSession,
                authorizationMethods: authorizationMethods
            )
        }
    }
    
    private func obtainAuthorizationCodeViaInteractiveEndpoint(
        endpoint: String,
        issuerMetadata: IssuerMetadata,
        clientMetadata: ClientMetadata,
        pkceSession: PKCESessionManager.PKCESession,
        credentialConfigurationId: String,
        authorizationMethods: [AuthorizationMethod]
    ) async throws -> String {
        
        print("Using Interactive Authorization Endpoint: \(endpoint) for issuer=\(issuerMetadata.credentialIssuer)"
        )
        
        let response: AuthorizationResponse
        do {
            response = try await interactiveAuthorizationHandler.handle(
                endpoint: endpoint,
                clientMetadata: clientMetadata,
                credentialConfigurationId: credentialConfigurationId,
                authorizationMethods: authorizationMethods,
                pkceSession: pkceSession
            )
        } catch {
            throw DownloadFailedException(
                "Interactive authorization failed at endpoint \(endpoint): \(error.localizedDescription)"
            )
        }
        
        guard let authorizationCode = response.authorizationCode else {
            throw DownloadFailedException(
                """
                Authorization failed: code not received from interactive \
                authorization endpoint \(endpoint).
                Error: \(response.error ?? "unknown"),
                Description: \(response.errorDescription ?? "unknown")
                """
            )
        }
        
        return authorizationCode
    }
    
    private func obtainAuthorizationCodeViaStandardRedirectToWeb(
        authorizationServerMetadata: AuthorizationServerMetadata,
        authorizeUser: AuthorizeUserCallback? = nil,
        issuerMetadata: IssuerMetadata,
        clientMetadata: ClientMetadata,
        pkceSession: PKCESessionManager.PKCESession,
        authorizationMethods: [AuthorizationMethod]? = nil
    ) async throws -> String {
        
        guard let authorizationEndpoint =
                authorizationServerMetadata.authorizationEndpoint else {
            throw DownloadFailedException(
                "Missing authorization endpoint for issuer \(issuerMetadata.credentialIssuer)"
            )
        }
        
        let redirectToWebAuthMethod =
        authorizationMethods?
            .first {
                if case .redirectToWeb = $0 { return true }
                return false
            }
        
        if let redirectMethod = redirectToWebAuthMethod,
           case let .redirectToWeb(openWebPage) = redirectMethod {
            
            print(
                "Using non-interactive authorization endpoint: \(authorizationEndpoint) " +
                "(redirect_to_web) for issuer=\(issuerMetadata.credentialIssuer)"
            )
            
            let requestData = StandardAuthorizationRequestData(
                authorizeUrl: authorizationEndpoint,
                clientMetadata: clientMetadata,
                pkceSession: pkceSession,
                scope: issuerMetadata.scope ?? "default"
            )
            
            let response: AuthorizationResponse
            do {
                response = try await RedirectToWebAuthorizationMethodService(
                    openWebPage: openWebPage
                ).authorizeUser(requestData: requestData)
            } catch {
                throw DownloadFailedException(
                    "Redirect-to-web authorization failed at endpoint \(authorizationEndpoint): \(error.localizedDescription)"
                )
            }
            
            guard let authorizationCode = response.authorizationCode else {
                throw DownloadFailedException(
                    "Authorization code not received from non-interactive authorization endpoint \(authorizationEndpoint)"
                )
            }
            
            return authorizationCode
            
        } else {
            
            guard let authorizationCode =
                    try await authorizeUser?(authorizationEndpoint) else {
                throw DownloadFailedException(
                    "No authorization method available to obtain authorization code from \(authorizationEndpoint)"
                )
            }
            
            return authorizationCode
        }
    }
    
}


class InteractiveAuthorizationResponse {

    let status: String?
    let type: String?
    let authSession: String?

    init(
        status: String?,
        type: String?,
        authSession: String?
    ) {
        self.status = status
        self.type = type
        self.authSession = authSession

        try Self.validateCommonFields(
            status: status,
            type: type,
            authSession: authSession
        )
    }

    private static func validateCommonFields(
        status: String?,
        type: String?,
        authSession: String?
    ) throws {

        guard let status, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IllegalArgumentException("Missing or empty 'status' field")
        }

        if status == "require_interaction" {
            guard let type, !type.isEmpty else {
                throw IllegalArgumentException(
                    "'type' is required when status is 'require_interaction'"
                )
            }

            guard let authSession, !authSession.isEmpty else {
                throw IllegalArgumentException(
                    "'authSession' is required when status is 'require_interaction'"
                )
            }
        }
    }

    /// Subclasses must implement their own validation logic
    func validate() throws {
        fatalError("Subclasses must override validate()")
    }
}
