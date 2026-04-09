class TrustedIssuerFlowHandler {
    private let authorizationCodeFlowService: AuthorizationCodeFlowService
    private let issuerMetadataService: IssuerMetadataService

    init(authService: AuthorizationCodeFlowService = AuthorizationCodeFlowService(), issuerMetadataService: IssuerMetadataService = IssuerMetadataService()) {
        authorizationCodeFlowService = authService
        self.issuerMetadataService = issuerMetadataService
    }

    func downloadCredentials(
        credentialIssuer: String,
        credentialConfigurationId: String,
        clientMetadata: ClientMetadata,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallback,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis,
        networkSession: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponse {
        let issuerMetadata = try await loadIssuerMetadata(
            credentialIssuer: credentialIssuer,
            credentialConfigurationId: credentialConfigurationId
        )
        let proofSigningAlgorithms = issuerMetadata.extractJwtProofSigningAlgorithms(
            credentialConfigurationId: credentialConfigurationId
        )

        switch issuerMetadata.issuerMetadata.specVersion {
        case .v1:
            return try await authorizationCodeFlowService.requestCredentials(
                issuerMetadata: issuerMetadata.issuerMetadata,
                clientMetadata: clientMetadata,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofs: getProofs,
                credentialConfigurationId: credentialConfigurationId,
                proofSigningAlgorithmsSupported: proofSigningAlgorithms,
                downloadTimeOutInMillis: downloadTimeoutInMillis,
                session: networkSession
            )

        case .draft13:
            let proofJwtCallback: ProofJwtCallback = { issuer, nonce, algs in
                let proofs = try await getProofs(issuer, nonce, algs)
                guard let jwt = proofs.firstProof else {
                    throw DownloadFailedException("Draft13 issuer requires a single JWT proof")
                }
                return jwt
            }
            let draft13Response = try await authorizationCodeFlowService.requestCredentialsDraft13(
                issuerMetadata: issuerMetadata.issuerMetadata,
                clientMetadata: clientMetadata,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofJwt: proofJwtCallback,
                credentialConfigurationId: credentialConfigurationId,
                proofSigningAlgorithmsSupported: proofSigningAlgorithms,
                downloadTimeOutInMillis: downloadTimeoutInMillis,
                session: networkSession
            )
            return CredentialResponse(
                credentials: [draft13Response.credential],
                credentialIssuer: draft13Response.credentialIssuer,
                credentialConfigurationId: draft13Response.credentialConfigurationId
            )
        }
    }


    private func loadIssuerMetadata(
        credentialIssuer: String,
        credentialConfigurationId: String
    ) async throws -> IssuerMetadataResult {
        try await issuerMetadataService.fetchIssuerMetadataResult(
            credentialIssuer: credentialIssuer,
            credentialConfigurationId: credentialConfigurationId
        )
    }
}
