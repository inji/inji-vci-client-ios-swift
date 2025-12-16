import Foundation
import OpenID4VPBridge
import OpenID4VP

class PresentationDuringIssuanceAuthorizationMethodService: AuthorizationMethodService {
    
    private let selectCredentialsForPresentation: SelectCredentialsForPresentationCallback
    private let signVerifiablePresentation: SignVerifiablePresentationCallback
    private let openId4vp: OpenID4VP
    private let handlePresentationTimeoutMs: Int64
    private let signVPTokensTimeoutMs: Int64
    
    init(
        selectCredentialsForPresentation: @escaping SelectCredentialsForPresentationCallback,
        signVerifiablePresentation: @escaping SignVerifiablePresentationCallback,
    ) {
        self.selectCredentialsForPresentation = selectCredentialsForPresentation
        self.signVerifiablePresentation = signVerifiablePresentation
        //TODO: get traceabilityId from vci client instance
        self.openId4vp = OpenID4VP(traceabilityId: "", walletMetadata: nil)
        self.handlePresentationTimeoutMs = 500 * 1000
        self.signVPTokensTimeoutMs = 5 * 1000
    }
    
    func type() -> String {
        return InteractionType.openId4VpPresentation.rawValue
    }
    
    func authorizeUser(requestData: AuthorizationRequestData) async -> AuthorizationResponse {
        let vpResponse: [String: Any]
        guard let presentationRequestData = requestData as? PresentationDuringIssuanceRequestData else {
            return errorResponse(error: "invalid_request", description: "Expected PresentationDuringIssuanceRequestData")
        }
        
        let authSession = presentationRequestData.authSession
        do {
            do {
                let vpRequest = try await validatePresentationRequest(request: presentationRequestData.ovpRequest)
                vpResponse = try await handlePresentation(vpRequest: vpRequest)
                //TODO: removed extra wrapping of InteractiveAuthorizationException on sendOVPAuthorizationResponseToIssuer
            } catch {
                print("Error during presentation handling: \(error.localizedDescription)")
                vpResponse = openId4vp.constructErrorInfo(exception: error)
            }
            
            return try await sendOVPAuthorizationResponseToIssuer(
                iar: presentationRequestData.iar,
                authSession: authSession,
                vpResponse: vpResponse
            )
        } catch let ex as InteractiveAuthorizationException {
            return errorResponse(error: ex.code, description: ex.message, authSession: presentationRequestData.authSession)
        } catch {
            return errorResponse(error: "server_error", description: "Unexpected error occurred: \(error.localizedDescription)")
        }
    }
    
    // TODO: changed validateAuthorizationRequest to validatePresentationRequest to avoid confusion
    private func validatePresentationRequest(request: [String: Any]) async throws -> AuthorizationRequest {
        do {
            return try await openId4vp.authenticateVerifier(authRequest: request, trustedVerifiers: [], shouldValidateClient: false)
        } catch {
            // TODO: changed validateAuthorizationRequest to validatePresentationRequest to avoid confusion
            throw InteractiveAuthorizationException(code: (error as? OpenID4VPException)?.errorCode ?? "invalid_request", message: "Malformed authorization request. \(error.localizedDescription)")
        }
    }
    
    private func handlePresentation(vpRequest: AuthorizationRequest) async throws -> [String: Any] {
        let selectedCredentials: [String: [FormatType: [OpenID4VPAnyCodable]]]
        do {
            selectedCredentials = try await withTimeout(milliseconds: handlePresentationTimeoutMs) {
                try await self.selectCredentialsForPresentation(vpRequest)
            }
        } catch {
            //TODO: check the error code needs to be server_error or access_denied
            throw InteractiveAuthorizationException(code: "server_error", message: "Failed to fetch matching credentials. \(error.localizedDescription)")
        }
        
        //TODO: populate holderId and signatureSuite properly
        // take the first ldp_vc from selectedCredentials - extract holderId and signatureSuite from there
        let holderId = "did:example:holder"
        let publicKey : PublicKeyType = try await DidPublicKeyResolver().resolve(uri: holderId)
        
        let signatureSuite: String
        switch publicKey {
        case .ed25519(let edKey):
            signatureSuite = "Ed25519Signature2020"
        default:
            signatureSuite = "JsonWebSignature2020"
        }
        
        let unsignedVpTokens: [FormatType: UnsignedVPToken]
        do {
            unsignedVpTokens = try await openId4vp.constructUnsignedVPToken(
                verifiableCredentials: selectedCredentials,
                holderId: holderId,
                signatureSuite: signatureSuite
            )
        } catch {
            //TODO: check the error code needs to be server_error or any other
            throw InteractiveAuthorizationException(code: "server_error", message: "Failed to construct unsigned VP token. \(error.localizedDescription)")
        }
        
        let signedVpTokens: [FormatType: VPTokenSigningResult]
        do {
            signedVpTokens = try await withTimeout(milliseconds: signVPTokensTimeoutMs) {
                try await self.signVerifiablePresentation(unsignedVpTokens)
            }
        } catch {
            //TODO: check the error code needs to be server_error or any other
            throw InteractiveAuthorizationException(code: "server_error", message: "Failed to sign VP token. \(error.localizedDescription)")
        }
        
        let vpResponse: [String: Any]
        do {
            vpResponse = try openId4vp.constructVPResponse(
                vpTokenSigningResults: signedVpTokens
            )
        } catch {
            throw InteractiveAuthorizationException(code: "server_error", message: "Failed to construct VP response. \(error.localizedDescription)")
        }
        
        return vpResponse
    }
    
    private func sendOVPAuthorizationResponseToIssuer(
        iar: String,
        authSession: String,
        vpResponse: [String: Any]
    ) async throws -> AuthorizationResponse {
        let response: NetworkResponse
        do {
            let vpResponseJson = try JSONSerialization.data(withJSONObject: vpResponse)
            let vpResponseString = String(data: vpResponseJson, encoding: .utf8) ?? ""
            
            response = try await NetworkManager.shared.sendRequest(
                url: iar,
                method: .post,
                bodyParams: [
                    "openid4vp_response": vpResponseString,
                    "auth_session": authSession
                ]
            )
        } catch {
            throw InteractiveAuthorizationException(
                code: "network_error",
                message: "Network error while posting VP response. \(error.localizedDescription)"
            )
        }
        
        guard let data = response.body.data(using: .utf8),
              let authorizationResponse = try? JSONDecoder().decode(AuthorizationResponse.self, from: data) else {
            throw InteractiveAuthorizationException(
                code: "invalid_response",
                message: "Issuer response deserialization failed."
            )
        }
        
        return authorizationResponse
    }
    
    private func errorResponse(
        error: String,
        description: String,
        authSession: String? = nil
    ) -> AuthorizationResponse {
        return AuthorizationResponse(
            authorizationCode: nil,
            status: "error",
            error: error,
            errorDescription: description,
            authSession: authSession ?? ""
        )
    }
    
    // Helper function for timeout
    private func withTimeout<T>(milliseconds: Int64, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

struct TimeoutError: Error {}
