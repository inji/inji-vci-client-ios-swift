import Foundation

public class VCIClient {
    let networkSession: NetworkManager
    let traceabilityId: String
    let credentialOfferFlowHandler: CredentialOfferFlowHandler
    let trustedIssuerFlowHandler: TrustedIssuerFlowHandler
    let issuerMetadataService: IssuerMetadataService
    let credentialRequestFactory: CredentialRequestFactoryProtocol

    public init(traceabilityId: String
    ) {
        self.traceabilityId = traceabilityId
        credentialOfferFlowHandler = CredentialOfferFlowHandler()
        trustedIssuerFlowHandler = TrustedIssuerFlowHandler()
        issuerMetadataService = IssuerMetadataService()
        networkSession = NetworkManager.shared
        credentialRequestFactory = CredentialRequestFactoryDraft13()
    }

    init(traceabilityId: String?,
         networkSession: NetworkManager? = nil,
         credentialRequestFactory: CredentialRequestFactoryProtocol? = nil,
         credentialOfferHandler: CredentialOfferFlowHandler? = nil,
         trustedIssuerFlowHandler: TrustedIssuerFlowHandler? = nil,
         issuerMetadataService: IssuerMetadataService? = nil
    ) {
        self.traceabilityId = traceabilityId ?? ""
        self.networkSession = networkSession ?? NetworkManager.shared
        credentialOfferFlowHandler = credentialOfferHandler ?? CredentialOfferFlowHandler()
        self.trustedIssuerFlowHandler = trustedIssuerFlowHandler ?? TrustedIssuerFlowHandler()
        self.issuerMetadataService = issuerMetadataService ?? IssuerMetadataService()
        self.credentialRequestFactory = credentialRequestFactory ?? CredentialRequestFactoryDraft13()
    }

    private var logTag: String {
        Util.getLogTag(className: String(describing: type(of: self)), traceabilityId: traceabilityId)
    }

    public func getIssuerMetadata(credentialIssuer: String) async throws -> [String: Any] {
        do {
            return try await issuerMetadataService.fetchAndParseIssuerMetadata(from: credentialIssuer)
        } catch {
            throw mapToVciClientException(error)
        }
    }

    public func getCredentialConfigurationsSupported(credentialIssuer: String) async throws -> [String: Any] {
        do {
            return try await issuerMetadataService.fetchCredentialConfigurationsSupported(from: credentialIssuer)
        } catch {
            throw mapToVciClientException(error)
        }
    }
    
    public func fetchCredentialFromTrustedIssuer(
        credentialIssuer: String,
        credentialConfigurationId: String,
        clientMetadata: ClientMetadata,
        getTokenResponse: @escaping TokenResponseCallback,
        authorizationMethods: [AuthorizationMethod],
        getProofJwt: @escaping ProofJwtCallback,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse {

        do {
            return try await self.trustedIssuerFlowHandler.downloadCredentialsDraft13(
                credentialIssuer: credentialIssuer,
                credentialConfigurationId: credentialConfigurationId,
                clientMetadata: clientMetadata,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofJwt: getProofJwt,
                downloadTimeoutInMillis: downloadTimeoutInMillis
            )
        } catch {
            print("Downloading credential failed due to \(error.localizedDescription)")
            throw mapToVciClientException(error)
        }
    }

    public func fetchCredentialsFromTrustedIssuer(
        credentialIssuer: String,
        credentialConfigurationId: String,
        clientMetadata: ClientMetadata,
        getTokenResponse: @escaping TokenResponseCallback,
        authorizationMethods: [AuthorizationMethod],
        getProofs: @escaping ProofsCallbackSpecVersion1,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponseSpecVersion1 {

        do {
            return try await self.trustedIssuerFlowHandler.downloadCredentials(
                credentialIssuer: credentialIssuer,
                credentialConfigurationId: credentialConfigurationId,
                clientMetadata: clientMetadata,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofs: getProofs,
                downloadTimeoutInMillis: downloadTimeoutInMillis
            )
        } catch {
            print("Downloading credential failed due to \(error.localizedDescription)")
            throw mapToVciClientException(error)
        }
    }

    @available(*, deprecated, renamed: "fetchCredentialsFromTrustedIssuer", message: "Use fetchCredentialsFromTrustedIssuer() for Spec Version 1 proofs-based downloads.")
    public func fetchCredentialFromTrustedIssuer(
        credentialIssuer: String,
        credentialConfigurationId: String,
        clientMetadata: ClientMetadata,
        getTokenResponse: @escaping TokenResponseCallback,
        authorizationMethods: [AuthorizationMethod],
        getProofs: @escaping ProofsCallbackSpecVersion1,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponseSpecVersion1 {
        try await fetchCredentialsFromTrustedIssuer(
            credentialIssuer: credentialIssuer,
            credentialConfigurationId: credentialConfigurationId,
            clientMetadata: clientMetadata,
            getTokenResponse: getTokenResponse,
            authorizationMethods: authorizationMethods,
            getProofs: getProofs,
            downloadTimeoutInMillis: downloadTimeoutInMillis
        )
    }

    
    public func fetchCredentialUsingCredentialOffer(
        credentialOffer: String,
        clientMetadata: ClientMetadata,
        getTxCode: TxCodeCallback,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        onCheckIssuerTrust: CheckIssuerTrustCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse? {

        do {
            return try await self.credentialOfferFlowHandler.downloadCredentialsDraft13(
                credentialOffer: credentialOffer,
                clientMetadata: clientMetadata,
                getTxCode: getTxCode,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofJwt: getProofJwt,
                onCheckIssuerTrust: onCheckIssuerTrust,
                networkSession: networkSession,
                downloadTimeoutInMillis: downloadTimeoutInMillis
            )
        } catch {
            print("Downloading credential failed due to \(error.localizedDescription)")
            throw mapToVciClientException(error)
        }
    }

    public func fetchCredentialsUsingCredentialOffer(
        credentialOffer: String,
        clientMetadata: ClientMetadata,
        getTxCode: TxCodeCallback,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallbackSpecVersion1,
        onCheckIssuerTrust: CheckIssuerTrustCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponseSpecVersion1 {

        do {
            return try await self.credentialOfferFlowHandler.downloadCredentials(
                credentialOffer: credentialOffer,
                clientMetadata: clientMetadata,
                getTxCode: getTxCode,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofs: getProofs,
                onCheckIssuerTrust: onCheckIssuerTrust,
                networkSession: networkSession,
                downloadTimeoutInMillis: downloadTimeoutInMillis
            )
        } catch {
            print("Downloading credential failed due to \(error.localizedDescription)")
            throw mapToVciClientException(error)
        }
    }

    @available(*, deprecated, renamed: "fetchCredentialsUsingCredentialOffer", message: "Use fetchCredentialsUsingCredentialOffer() for Spec Version 1 proofs-based downloads.")
    public func fetchCredentialUsingCredentialOffer(
        credentialOffer: String,
        clientMetadata: ClientMetadata,
        getTxCode: TxCodeCallback,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallbackSpecVersion1,
        onCheckIssuerTrust: CheckIssuerTrustCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponseSpecVersion1 {
        try await fetchCredentialsUsingCredentialOffer(
            credentialOffer: credentialOffer,
            clientMetadata: clientMetadata,
            getTxCode: getTxCode,
            authorizationMethods: authorizationMethods,
            getTokenResponse: getTokenResponse,
            getProofs: getProofs,
            onCheckIssuerTrust: onCheckIssuerTrust,
            downloadTimeoutInMillis: downloadTimeoutInMillis
        )
    }
    
    @available(*, deprecated, renamed: "fetchCredentialFromTrustedIssuer", message: "This method is deprecated as per the new VCI Client library contract. Use fetchCredentialFromTrustedIssuer()")
    public func requestCredentialFromTrustedIssuer(
        credentialIssuer: String,
        credentialConfigurationId: String,
        clientMetadata: ClientMetadata,
        authorizeUser: @escaping AuthorizeUserCallback,
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse? {
        do {
            return try await trustedIssuerFlowHandler.downloadCredentialsDraft13(
                credentialIssuer: credentialIssuer,
                credentialConfigurationId: credentialConfigurationId,
                clientMetadata: clientMetadata,
                authorizationMethods: wrapAuthorizeUser(authorizeUser),
                getTokenResponse: getTokenResponse,
                getProofJwt: getProofJwt,
                downloadTimeoutInMillis: downloadTimeoutInMillis,
                networkSession: networkSession
            )
        } catch {
            throw mapToVciClientException(error)
        }
    }
    
    @available(*, deprecated, renamed: "fetchCredentialUsingCredentialOffer", message: "This method is deprecated as per the new VCI Client library contract. Use fetchCredentialUsingCredentialOffer()")
    public func requestCredentialByCredentialOffer(
        credentialOffer: String,
        clientMetadata: ClientMetadata,
        getTxCode: TxCodeCallback,
        authorizeUser: @escaping AuthorizeUserCallback,
        getTokenResponse: @escaping TokenResponseCallback,
        getProofJwt: @escaping ProofJwtCallback,
        onCheckIssuerTrust: CheckIssuerTrustCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse? {
        do {
            return try await credentialOfferFlowHandler.downloadCredentialsDraft13(
                credentialOffer: credentialOffer,
                clientMetadata: clientMetadata,
                getTxCode: getTxCode,
                authorizationMethods: wrapAuthorizeUser(authorizeUser),
                getTokenResponse: getTokenResponse,
                getProofJwt: getProofJwt,
                onCheckIssuerTrust: onCheckIssuerTrust,
                networkSession: networkSession,
                downloadTimeoutInMillis: downloadTimeoutInMillis
            )
        } catch {
            throw mapToVciClientException(error)
        }
    }


    @available(*, deprecated, message: "This method is deprecated as per the new VCI Client library contract.Use requestCredentialByCredentialOffer() or requestCredentialFromTrustedIssuer()")
    public func requestCredential(
        issuerMeta: IssuerMeta,
        proof: Proof,
        accessToken: String
    ) async throws -> CredentialResponse? {
        do {
            let issuerMetadata = IssuerMetadata(
                credentialIssuer: issuerMeta.credentialAudience,
                credentialEndpoint: issuerMeta.credentialEndpoint,
                credentialType: issuerMeta.credentialType,
                context: nil,
                credentialFormat: issuerMeta.credentialFormat,
                doctype: issuerMeta.docType,
                claims: issuerMeta.claims?.mapValues { AnyCodable($0) },
                authorizationServers: nil,
                tokenEndpoint: nil,
                scope: "openId"
            )
            var request = try credentialRequestFactory.createCredentialRequest(
                credentialFormat: issuerMetadata.credentialFormat,
                accessToken: accessToken,
                issuer: issuerMetadata,
                proofJwt: proof
            )

            request.timeoutInterval = TimeInterval(issuerMeta.downloadTimeoutInMilliseconds) / 1000

            let networkResponse = try await networkSession.sendRequest(request: request)
            let responseBody = networkResponse.body

            print("\(logTag) Credential downloaded successfully.")

            if !responseBody.isEmpty {
                guard let result = try JsonUtils.deserialize(responseBody, as: CredentialResponse.self) else {
                    throw DownloadFailedException("Failed to parse credential response.")
                }
                return result
            }

            print("\(logTag) Response body is empty.")
            return nil

        } catch let error as NetworkRequestTimeoutException {
            print("\(logTag) Request timed out after \(issuerMeta.downloadTimeoutInMilliseconds / 1000)s")
            throw error
        } catch let error as DownloadFailedException {
            throw error
        } catch let error as InvalidAccessTokenException {
            throw error
        } catch let error as InvalidPublicKeyException {
            throw error
        } catch {
            print("\(logTag) Unexpected error: \(error.localizedDescription)")
            throw DownloadFailedException(error.localizedDescription)
        }
    }
    
    // Wrap AuthorizeUserCallback into AuthorizationMethod.redirectToWeb
    private func wrapAuthorizeUser(_ authorizeUser: @escaping AuthorizeUserCallback) -> [AuthorizationMethod] {
        let redirectToWebMethod = AuthorizationMethod.redirectToWeb(openWebPage: { url in
            let authCode = try await authorizeUser(url)
            return ["code": authCode]
        })
        return [redirectToWebMethod]
    }
}
