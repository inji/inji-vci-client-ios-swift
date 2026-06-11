import OpenID4VP
import OpenID4VPBridge

internal protocol OpenID4VPInteracting {
    func authenticateVerifier(
        authRequest: [String: Any]
    ) async throws -> AuthorizationRequest
    
    func constructUnsignedVPToken(
        selectedCredentials: [String: [Credential]]
    ) async throws -> [UnsignedVPToken]
    
    func constructVPResponse(
        vpTokenSigningResults: [VPTokenSigningResult]
    ) -> [String: Any]
    
    func constructErrorInfo(exception: Error) -> [String: Any]
}

class OpenID4VPInteraction: OpenID4VPInteracting {
    private let openId4vp: OpenID4VP
    
    init(jsonLdCanonicalizer:JsonLdCanonicalizerCallback?, traceabilityId: String, openid4vpWalletConfig: WalletConfig) {
        openId4vp = OpenID4VP(traceabilityId: traceabilityId, walletConfig: openid4vpWalletConfig, jsonLdCanonicalizer: jsonLdCanonicalizer)
    }
    
    func authenticateVerifier(
        authRequest: [String: Any]
    ) async throws -> AuthorizationRequest {
        try await openId4vp.authenticateVerifier(
            authorizationRequest: authRequest
        )
    }
    
    func constructUnsignedVPToken(
        selectedCredentials verifiableCredentials: [String: [Credential]]
    ) async throws -> [UnsignedVPToken] {
        try await openId4vp.constructUnsignedVPToken(
            selectedCredentials: verifiableCredentials
        )
    }
    
    func constructVPResponse(
        vpTokenSigningResults: [VPTokenSigningResult]
    ) -> [String: Any] {
        openId4vp.constructVPResponse(vpTokenSigningResults: vpTokenSigningResults)
    }
    
    func constructErrorInfo(exception: Error) -> [String: Any] {
        openId4vp.constructErrorInfo(exception: exception)
    }
}
