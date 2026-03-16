import Foundation

class PreAuthCodeFlowService {
    private let authServerResolver: AuthorizationServerResolver
    private let tokenService: TokenService
    private let credentialExecutor: CredentialRequestExecutor

    init(
        authServerResolver: AuthorizationServerResolver = AuthorizationServerResolver(),
        tokenService: TokenService = TokenService(),
        credentialExecutor: CredentialRequestExecutor = CredentialRequestExecutor()
    ) {
        self.authServerResolver = authServerResolver
        self.tokenService = tokenService
        self.credentialExecutor = credentialExecutor
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

            let jwt = try await getProofJwt(
                issuerMetadata.credentialIssuer,
                token.cNonce,
                proofSigningAlgorithmsSupportedSupported
            )

            let proof = JWTProof(jwt: jwt)

            guard let credential = try await credentialExecutor.requestCredential(
                issuerMetadata: issuerMetadata,
                credentialConfigurationId: credentialConfigurationId,
                proof: proof,
                accessToken: token.accessToken,
                timeoutInMillis: downloadTimeoutInMillis
            ) else {
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
}
