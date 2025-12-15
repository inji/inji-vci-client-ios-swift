class CredentialOfferFlowHandler {
    private let credentialOfferService: CredentialOfferService
    private let issuerMetadataService: IssuerMetadataService
    private let preAuthFlowService: PreAuthCodeFlowService
    private let authorizationCodeFlowService: AuthorizationCodeFlowService

    init(
        credentialOfferService: CredentialOfferService = CredentialOfferService(),
        issuerMetadataService: IssuerMetadataService = IssuerMetadataService(),
        preAuthFlowService: PreAuthCodeFlowService = PreAuthCodeFlowService(),
        authorizationCodeFlowService: AuthorizationCodeFlowService = AuthorizationCodeFlowService()
    ) {
        self.credentialOfferService = credentialOfferService
        self.issuerMetadataService = issuerMetadataService
        self.preAuthFlowService = preAuthFlowService
        self.authorizationCodeFlowService = authorizationCodeFlowService
    }

    public func downloadCredentials(
        credentialOffer: String,
        clientMetadata: ClientMetadata,
        getTxCode: TxCodeCallback,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        onCheckIssuerTrust: CheckIssuerTrustCallback = nil,
        networkSession: NetworkManager = NetworkManager.shared,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse {
        let offer = try await credentialOfferService.fetchCredentialOffer(credentialOffer)
        
        if(offer.credentialConfigurationIds.count > 1){
            throw DownloadFailedException("Batch credential request is not supported")
        }

        let credentialConfigurationId = offer.credentialConfigurationIds.first ?? ""
        let issuerMetadataResponse = try await issuerMetadataService.fetchIssuerMetadataResult(credentialIssuer: offer.credentialIssuer, credentialConfigurationId: credentialConfigurationId
        )

        let issuerDisplay = (issuerMetadataResponse.raw["display"] as? [[String: Any]]) ?? [[:]]
        try await ensureIssuerTrust(
            credentialIssuer: offer.credentialIssuer,
            issuerDisplay: issuerDisplay,
            onCheckIssuerTrust: onCheckIssuerTrust
        )

        let proofSigningAlgorithmsSupportedSupported = issuerMetadataResponse.extractJwtProofSigningAlgorithms(credentialConfigurationId: credentialConfigurationId)

        if offer.isPreAuthorizedFlow {
            return try await preAuthFlowService.requestCredentials(
                issuerMetadata: issuerMetadataResponse.issuerMetadata,
                credentialOffer: offer,
                getTokenResponse: getTokenResponse,
                getProofJwt: getProofJwt,
                credentialConfigurationId: credentialConfigurationId,
                proofSigningAlgorithmsSupportedSupported: proofSigningAlgorithmsSupportedSupported,
                getTxCode: getTxCode,
                downloadTimeoutInMillis: downloadTimeoutInMillis
            )
        } else if offer.isAuthorizationCodeFlow {
            return try await authorizationCodeFlowService.requestCredentials(
                issuerMetadata: issuerMetadataResponse.issuerMetadata,
                clientMetadata: clientMetadata,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofJwt: getProofJwt,
                credentialConfigurationId: offer.credentialConfigurationIds.first!,
                proofSigningAlgorithmsSupportedSupported: proofSigningAlgorithmsSupportedSupported,
                credentialOffer: offer,
                downloadTimeOutInMillis: downloadTimeoutInMillis
            )
        } else {
            throw CredentialOfferFetchFailedException("Credential offer does not contain a supported grant type")
        }
    }

    private func ensureIssuerTrust(
        credentialIssuer: String,
        issuerDisplay: [[String: Any]],
        onCheckIssuerTrust: CheckIssuerTrustCallback
    ) async throws {
        guard let onCheck = onCheckIssuerTrust else { return }

        let consented = try await onCheck(credentialIssuer, issuerDisplay)
        if !consented {
            throw CredentialOfferFetchFailedException("Issuer not trusted by user")
        }
    }
}
