import OpenID4VP
import OpenID4VPBridge

internal protocol OpenID4VPInteracting {
    func authenticateVerifier(
        authRequest: [String: Any],
        trustedVerifiers: [Verifier],
        shouldValidateClient: Bool
    ) async throws -> AuthorizationRequest
    
    func constructUnsignedVPToken(
        verifiableCredentials: [String: [FormatType: [OpenID4VPAnyCodable]]],
        holderId: String?,
        ldpVpSignatureSuite: String?
    ) async throws -> [UnsignedVPToken]
    
    func constructVPResponse(
        vpTokenSigningResults: [VPTokenSigningResult]
    ) -> [String: Any]
    
    func constructErrorInfo(exception: Error) -> [String: Any]
}

class OpenID4VPInteraction: OpenID4VPInteracting {
    private let openId4vp: OpenID4VP
    
    init(traceabilityId: String) {
        openId4vp = OpenID4VP(traceabilityId: traceabilityId, walletMetadata: nil)
    }
    
    func authenticateVerifier(
        authRequest: [String: Any],
        trustedVerifiers: [Verifier],
        shouldValidateClient: Bool
    ) async throws -> AuthorizationRequest {
        try await openId4vp.authenticateVerifier(
            authorizationRequest: authRequest,
            trustedVerifiers: trustedVerifiers,
            shouldValidateClient: shouldValidateClient
        )
    }
    
    func constructUnsignedVPToken(
        verifiableCredentials: [String: [FormatType: [OpenID4VPAnyCodable]]],
        holderId: String?,
        ldpVpSignatureSuite: String?
    ) async throws -> [UnsignedVPToken] {
        try await openId4vp.constructUnsignedVPToken(
            verifiableCredentials: verifiableCredentials,
            holderId: holderId,
            signatureSuite: ldpVpSignatureSuite
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
