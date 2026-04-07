import Foundation

public class VCIClient {
    let networkSession: NetworkManager
    let traceabilityId: String
    let credentialOfferFlowHandler: CredentialOfferFlowHandler
    let trustedIssuerFlowHandler: TrustedIssuerFlowHandler
    let issuerMetadataService: IssuerMetadataService

    public init(traceabilityId: String
    ) {
        self.traceabilityId = traceabilityId
        credentialOfferFlowHandler = CredentialOfferFlowHandler()
        trustedIssuerFlowHandler = TrustedIssuerFlowHandler()
        issuerMetadataService = IssuerMetadataService()
        networkSession = NetworkManager.shared
    }

    init(traceabilityId: String?,
         networkSession: NetworkManager? = nil,
         credentialOfferHandler: CredentialOfferFlowHandler? = nil,
         trustedIssuerFlowHandler: TrustedIssuerFlowHandler? = nil,
         issuerMetadataService: IssuerMetadataService? = nil
    ) {
        self.traceabilityId = traceabilityId ?? ""
        self.networkSession = networkSession ?? NetworkManager.shared
        credentialOfferFlowHandler = credentialOfferHandler ?? CredentialOfferFlowHandler()
        self.trustedIssuerFlowHandler = trustedIssuerFlowHandler ?? TrustedIssuerFlowHandler()
        self.issuerMetadataService = issuerMetadataService ?? IssuerMetadataService()
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
    
    public func fetchCredentialsFromTrustedIssuer(
        credentialIssuer: String,
        credentialConfigurationId: String,
        clientMetadata: ClientMetadata,
        getTokenResponse: @escaping TokenResponseCallback,
        authorizationMethods: [AuthorizationMethod],
        getProofs: @escaping ProofsCallback,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse {

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
            Util.logError(
                message: "Downloading credential failed due to \(error.localizedDescription)",
                className: "VCIClient"
            )
            throw mapToVciClientException(error)
        }
    }

    public func fetchCredentialsUsingCredentialOffer(
        credentialOffer: String,
        clientMetadata: ClientMetadata,
        getTxCode: TxCodeCallback,
        authorizationMethods: [AuthorizationMethod],
        getTokenResponse: @escaping TokenResponseCallback,
        getProofs: @escaping ProofsCallback,
        onCheckIssuerTrust: CheckIssuerTrustCallback = nil,
        downloadTimeoutInMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> CredentialResponse {

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
            Util.logError(
                message: "Downloading credential failed due to \(error.localizedDescription)",
                className: "VCIClient"
            )
            throw mapToVciClientException(error)
        }
    }
}
