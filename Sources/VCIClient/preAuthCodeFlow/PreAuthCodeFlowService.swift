import Foundation

class PreAuthCodeFlowService {
    private let authServerResolver: AuthorizationServerResolver
    private let tokenService: TokenService
    private let credentialExecutor: CredentialRequestExecutor
    private let nonceService: NonceService

    init(
        authServerResolver: AuthorizationServerResolver = AuthorizationServerResolver(),
        tokenService: TokenService = TokenService(),
        credentialExecutor: CredentialRequestExecutor = CredentialRequestExecutor(),
        nonceService: NonceService = NonceService()
    ) {
        self.authServerResolver = authServerResolver
        self.tokenService = tokenService
        self.credentialExecutor = credentialExecutor
        self.nonceService = nonceService
    }

    func requestCredentials(
        issuerMetadata: IssuerMetadata,
        credentialOffer: CredentialOffer,
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallbackSpecVersion1,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        getTxCode: TxCodeCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponseSpecVersion1 {
        try await executeRequestCredentials(
            issuerMetadata: issuerMetadata,
            credentialOffer: credentialOffer,
            getTokenResponse: getTokenResponse,
            credentialConfigurationId: credentialConfigurationId,
            proofSigningAlgorithmsSupportedSupported: proofSigningAlgorithmsSupportedSupported,
            getTxCode: getTxCode,
            downloadTimeoutInMillis: downloadTimeoutInMillis
        ) { token in
            let proofs: CredentialRequestProofs
            let nonce = try await resolveNonce(issuerMetadata: issuerMetadata, timeoutInMillis: downloadTimeoutInMillis)
            do {
                proofs = try await getProofs(
                    issuerMetadata.credentialIssuer,
                    nonce,
                    proofSigningAlgorithmsSupportedSupported
                )
            } catch {
                throw DownloadFailedException("Failed to obtain proofs from callback: \(error.localizedDescription)")
            }

            return try await self.credentialExecutor.requestCredential(
                issuerMetadata: issuerMetadata,
                credentialConfigurationId: credentialConfigurationId,
                proofs: proofs,
                accessToken: token.accessToken,
                timeoutInMillis: downloadTimeoutInMillis
            )
        }
    }

    func requestCredentialsDraft13(
        issuerMetadata: IssuerMetadata,
        credentialOffer: CredentialOffer,
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        getTxCode: TxCodeCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse {
        let response = try await executeRequestCredentials(
            issuerMetadata: issuerMetadata,
            credentialOffer: credentialOffer,
            getTokenResponse: getTokenResponse,
            credentialConfigurationId: credentialConfigurationId,
            proofSigningAlgorithmsSupportedSupported: proofSigningAlgorithmsSupportedSupported,
            getTxCode: getTxCode,
            downloadTimeoutInMillis: downloadTimeoutInMillis
        ) { token in
            let nonce = try resolveNonceDraft13(tokenResponse: token, timeoutInMillis: downloadTimeoutInMillis)
            let jwt: String
            do {
                jwt = try await getProofJwt(
                    issuerMetadata.credentialIssuer,
                    nonce,
                    proofSigningAlgorithmsSupportedSupported
                )
            } catch {
                throw DownloadFailedException("Failed to obtain proof JWT from callback: \(error.localizedDescription)")
            }

            return try await self.credentialExecutor.requestCredentialDraft13(
                issuerMetadata: issuerMetadata,
                credentialConfigurationId: credentialConfigurationId,
                proof: JWTProof(jwt: jwt),
                accessToken: token.accessToken,
                timeoutInMillis: downloadTimeoutInMillis
            )
        }

        return response
    }

    private func executeRequestCredentials<Response>(
        issuerMetadata: IssuerMetadata,
        credentialOffer: CredentialOffer,
        getTokenResponse: @escaping TokenResponseCallback,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        getTxCode: TxCodeCallback,
        downloadTimeoutInMillis: Int64,
        requestCredential: (TokenResponse) async throws -> Response?
    ) async throws -> Response {
        do {
            let authServerMetadata = try await authServerResolver
                .resolveForPreAuth(
                    issuerMetadata: issuerMetadata,
                    credentialOffer: credentialOffer
                )

            guard let tokenEndpoint = authServerMetadata.tokenEndpoint else {
                throw DownloadFailedException(
                    "Token endpoint is missing in Authorization Server metadata."
                )
            }

            guard let grant = credentialOffer.grants?.preAuthorizedGrant else {
                throw InvalidDataProvidedException(
                    "Missing pre-authorized grant details."
                )
            }

            let txCode: String? = try await {
                if let txCodeObject = grant.txCode {
                    return try await getTxCode?(txCodeObject.inputMode, txCodeObject.description, txCodeObject.length)
                } else {
                    return nil
                }
            }()

            if grant.txCode != nil && txCode == nil {
                throw DownloadFailedException(
                    "tx_code required but no provider was given."
                )
            }

            let token = try await tokenService.getAccessToken(
                getTokenResponse: getTokenResponse,
                tokenEndpoint: tokenEndpoint,
                preAuthCode: grant.preAuthCode,
                txCode: txCode
            )


            guard let credential = try await requestCredential(token) else {
                throw DownloadFailedException("Credential request failed.")
            }

            return credential
        } catch let e as DownloadFailedException {
            throw e
        } catch let e as VCIClientException {
            throw DownloadFailedException(
                message: "Pre-Authorized Code Flow failed: \(e.message)",
                serverErrorCode: e.serverErrorCode,
                serverErrorDescription: e.serverErrorDescription,
                cause: e
            )
        } catch {
            throw DownloadFailedException(
                message: "Unexpected error during Pre-Authorized Code Flow: \(error.localizedDescription)",
                cause: error
            )
        }
    }

    func requestCredentials(
        issuerMetadata: IssuerMetadata,
        credentialOffer: CredentialOffer,
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        credentialConfigurationId: String,
        proofSigningAlgorithmsSupportedSupported: [String],
        getTxCode: TxCodeCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse {
        try await requestCredentialsDraft13(
            issuerMetadata: issuerMetadata,
            credentialOffer: credentialOffer,
            getTokenResponse: getTokenResponse,
            getProofJwt: getProofJwt,
            credentialConfigurationId: credentialConfigurationId,
            proofSigningAlgorithmsSupportedSupported: proofSigningAlgorithmsSupportedSupported,
            getTxCode: getTxCode,
            downloadTimeoutInMillis: downloadTimeoutInMillis
        )
    }

    private func resolveNonceDraft13(
        tokenResponse: TokenResponse,
        timeoutInMillis: Int64
    ) throws -> String? {
        if let cNonce = tokenResponse.cNonce, !cNonce.isEmpty {
            return cNonce
        }
        throw DownloadFailedException("No c_nonce in token response")
    }

    private func resolveNonce(
        issuerMetadata: IssuerMetadata,
        timeoutInMillis: Int64
    ) async throws -> String? {
        return try await nonceService.fetchNonce(
            issuerMetadata: issuerMetadata,
            timeoutInMillis: timeoutInMillis
        )
    }
}
