import Foundation

public class VCIClient {
    let networkSession: NetworkManager
    let traceabilityId: String
    let credentialOfferFlowHandler: CredentialOfferFlowHandler
    let trustedIssuerFlowHandler: TrustedIssuerFlowHandler
    let issuerMetadataService: IssuerMetadataService
    private let dpopManager: DPoPManager
    private let dpopFlowLock = NSLock()
    private var dpopFlowActive = false

    public init(traceabilityId: String
    ) {
        self.traceabilityId = traceabilityId
        credentialOfferFlowHandler = CredentialOfferFlowHandler()
        trustedIssuerFlowHandler = TrustedIssuerFlowHandler()
        issuerMetadataService = IssuerMetadataService()
        networkSession = NetworkManager.shared
        dpopManager = DPoPManager()
    }

    init(traceabilityId: String?,
         networkSession: NetworkManager? = nil,
         credentialOfferHandler: CredentialOfferFlowHandler? = nil,
         trustedIssuerFlowHandler: TrustedIssuerFlowHandler? = nil,
         issuerMetadataService: IssuerMetadataService? = nil,
         dpopManager: DPoPManager? = nil
    ) {
        self.traceabilityId = traceabilityId ?? ""
        self.networkSession = networkSession ?? NetworkManager.shared
        credentialOfferFlowHandler = credentialOfferHandler ?? CredentialOfferFlowHandler()
        self.trustedIssuerFlowHandler = trustedIssuerFlowHandler ?? TrustedIssuerFlowHandler()
        self.issuerMetadataService = issuerMetadataService ?? IssuerMetadataService()
        self.dpopManager = dpopManager ?? DPoPManager()
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
    /// Generates a fresh token-endpoint DPoP proof bound to the supplied nonce, used by the wallet
    /// to retry the token POST after an authorization server `use_dpop_nonce` challenge. Valid only
    /// during an active flow; the ephemeral key from that flow signs the proof.
    public func generateTokenDPoPProof(dpopNonce: String) throws -> String {
        do {
            return try dpopManager.generateTokenProof(nonce: dpopNonce)
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
            try beginDpopFlow()
            defer { endDpopFlow() }
            return try await self.trustedIssuerFlowHandler.downloadCredentials(
                credentialIssuer: credentialIssuer,
                credentialConfigurationId: credentialConfigurationId,
                clientMetadata: clientMetadata,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofs: getProofs,
                downloadTimeoutInMillis: downloadTimeoutInMillis,
                dpopManager: dpopManager
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
            try beginDpopFlow()
            defer { endDpopFlow() }
            return try await self.credentialOfferFlowHandler.downloadCredentials(
                credentialOffer: credentialOffer,
                clientMetadata: clientMetadata,
                getTxCode: getTxCode,
                authorizationMethods: authorizationMethods,
                getTokenResponse: getTokenResponse,
                getProofs: getProofs,
                onCheckIssuerTrust: onCheckIssuerTrust,
                networkSession: networkSession,
                downloadTimeoutInMillis: downloadTimeoutInMillis,
                dpopManager: dpopManager
            )
        } catch {
            Util.logError(
                message: "Downloading credential failed due to \(error.localizedDescription)",
                className: "VCIClient"
            )
            throw mapToVciClientException(error)
        }
    }

    private func beginDpopFlow() throws {
        dpopFlowLock.lock()
        defer { dpopFlowLock.unlock() }

        guard !dpopFlowActive else {
            throw VCIClientException(
                code: "VCI-011",
                message: "A DPoP credential download flow is already active for this VCIClient instance"
            )
        }

        dpopManager.reset()
        dpopFlowActive = true
    }

    private func endDpopFlow() {
        dpopFlowLock.lock()
        dpopManager.reset()
        dpopFlowActive = false
        dpopFlowLock.unlock()
    }
}
