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
        signatureSuite: String?
    ) async throws -> [FormatType: UnsignedVPToken]

    func constructVPResponse(
        vpTokenSigningResults: [FormatType: VPTokenSigningResult]
    ) -> [String: Any]

    func constructErrorInfo(exception: Error) -> [String: Any]
}

class OpenID4VPInteraction : OpenID4VPInteracting {
    private let openId4vp: OpenID4VP
    
    init(traceabilityId: String) {
        self.openId4vp = OpenID4VP(traceabilityId: traceabilityId, walletMetadata: nil)
    }
    
    func authenticateVerifier(
        authRequest: [String: Any],
        trustedVerifiers: [Verifier],
        shouldValidateClient: Bool
    ) async throws -> AuthorizationRequest {
        try await self.openId4vp.authenticateVerifier(
            authRequest: authRequest,
            trustedVerifiers: trustedVerifiers,
            shouldValidateClient: shouldValidateClient
        )
    }

    func constructUnsignedVPToken(
        verifiableCredentials: [String: [FormatType: [OpenID4VPAnyCodable]]],
        holderId: String?,
        signatureSuite: String?
    ) async throws -> [FormatType: UnsignedVPToken] {
        try await self.openId4vp.constructUnsignedVPToken(
            verifiableCredentials: verifiableCredentials,
            holderId: holderId,
            signatureSuite: signatureSuite
        )
    }

    func constructVPResponse(
        vpTokenSigningResults: [FormatType: VPTokenSigningResult]
    ) -> [String: Any] {
        self.openId4vp.constructVPResponse(vpTokenSigningResults: vpTokenSigningResults)
    }

    func constructErrorInfo(exception: Error) -> [String: Any] {
        self.openId4vp.constructErrorInfo(exception: exception)
    }
}
