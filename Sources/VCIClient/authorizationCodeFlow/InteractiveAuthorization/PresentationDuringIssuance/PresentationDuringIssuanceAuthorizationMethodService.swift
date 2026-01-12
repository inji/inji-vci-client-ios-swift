import Foundation
import OpenID4VPBridge
import OpenID4VP

class PresentationDuringIssuanceAuthorizationMethodService: AuthorizationMethodService {
    
    private let selectCredentialsForPresentation: SelectCredentialsForPresentationCallback
    private let signVerifiablePresentation: SignVerifiablePresentationCallback
    private let openId4vp: OpenID4VPInteracting
    private let networkManager: NetworkManager
    private let resolvePublicKeyType: (_ uri: String) async throws -> String
    
    init(
        selectCredentialsForPresentation: @escaping SelectCredentialsForPresentationCallback,
        signVerifiablePresentation: @escaping SignVerifiablePresentationCallback,
        networkManager: NetworkManager = NetworkManager.shared,
        openId4vp: OpenID4VPInteracting? = nil,
        resolvePublicKeyType: ((_ uri: String) async throws -> String)? = nil
    ) {
        self.selectCredentialsForPresentation = selectCredentialsForPresentation
        self.signVerifiablePresentation = signVerifiablePresentation
        self.openId4vp = openId4vp ?? OpenID4VPInteraction(traceabilityId: Util.getTraceabilityId())
        self.networkManager = networkManager
        self.resolvePublicKeyType = resolvePublicKeyType ?? { uri in
            let publicKey = try await DidPublicKeyResolver().resolve(uri: uri)
            switch publicKey {
            case .ed25519(_):
                return "Ed25519Signature2020"
            default:
                return "JsonWebSignature2020"
            }
        }
    }
    
    func type() -> String {
        return InteractionType.openId4VpPresentation.rawValue
    }
    
    func authorizeUser(requestData: AuthorizationRequestData, networkTimeout: Int64 = Constants.defaultNetworkTimeoutInMillis) async throws -> AuthorizationResponse {
        let vpResponse: [String: Any]
        guard let presentationRequestData = requestData as? PresentationDuringIssuanceRequestData else {
            throw InteractiveAuthorizationException(message: "Expected PresentationDuringIssuanceRequestData")
        }
        
        let authSession = presentationRequestData.authSession
        do {
            do {
                let vpRequest = try await validatePresentationRequest(request: presentationRequestData.ovpRequest)
                vpResponse = try await handlePresentation(vpRequest: vpRequest)
            } catch {
                print("Error during presentation handling: \(error.localizedDescription)")
                vpResponse = openId4vp.constructErrorInfo(exception: error)
            }
            
            return try await sendOVPAuthorizationResponseToIssuer(
                iar: presentationRequestData.iar,
                authSession: authSession,
                vpResponse: vpResponse,
                networkTimeout: networkTimeout
            )
        } catch let ex as InteractiveAuthorizationException {
            print("InteractiveAuthorizationException: \(ex.message)")
            throw ex
        } catch {
            throw InteractiveAuthorizationException(message: "Unexpected error occurred: \(error.localizedDescription)")
        }
    }
    
    private func validatePresentationRequest(request: [String: Any]) async throws -> AuthorizationRequest {
        return try await openId4vp.authenticateVerifier(authRequest: request, trustedVerifiers: [Verifier](), shouldValidateClient: false)
    }
    
    private func handlePresentation(vpRequest: AuthorizationRequest) async throws -> [String: Any] {
        let selectedCredentials: [String: [FormatType: [OpenID4VPAnyCodable]]] = try await self.selectCredentialsForPresentation(vpRequest)
        if(selectedCredentials.isEmpty) {
            throw AccessDenied(message: "No credentials selected by user", className: "PresentationDuringIssuanceAuthorizationMethodService")
        }
        
        let holderId: String? = extractHolderId(credentials: selectedCredentials)
        let signatureSuite: String? = try await resolveSignatureSuite(for: holderId)
        let unsignedVpTokens: [FormatType: UnsignedVPToken] = try await openId4vp.constructUnsignedVPToken(
            verifiableCredentials: selectedCredentials,
            holderId: holderId,
            signatureSuite: signatureSuite
        )
        let signedVpTokens: [FormatType: VPTokenSigningResult] = try await self.signVerifiablePresentation(unsignedVpTokens)
        
        return openId4vp.constructVPResponse(vpTokenSigningResults: signedVpTokens)
    }
    
    private func extractHolderId(credentials: [String: [FormatType: [OpenID4VPAnyCodable]]]) -> String? {
        return credentials.values.compactMap { formatMap in
            guard let ldpVcCredentials = formatMap[.ldp_vc],
                  let firstLdpVcCredential = ldpVcCredentials.first?.value as? [String: Any],
                  let credentialSubject = firstLdpVcCredential["credentialSubject"] as? [String: Any],
                  let holderId = credentialSubject["id"] as? String else {
                return nil
            }
            return holderId.trimmingCharacters(in: CharacterSet(charactersIn: "=")) + "#0"
        }.first
    }
    
    private func sendOVPAuthorizationResponseToIssuer(
        iar: String,
        authSession: String,
        vpResponse: [String: Any],
        networkTimeout: Int64
    ) async throws -> AuthorizationResponse {
        let response: NetworkResponse
        do {
            let vpResponseJson = try JSONSerialization.data(withJSONObject: vpResponse)
            let vpResponseString = String(data: vpResponseJson, encoding: .utf8) ?? ""
            
            response = try await networkManager.sendRequest(
                url: iar,
                method: .post,
                headers: ["Content-Type": ContentTypes.applicationFormUrlEncoded.rawValue],
                bodyParams: [
                    "openid4vp_response": vpResponseString,
                    "auth_session": authSession
                ],
                timeoutMillis: networkTimeout
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
    
    private func resolveSignatureSuite(for holderId: String?) async throws -> String? {
        if let holderId = holderId {
            return try await resolvePublicKeyType(holderId)
        }
        return nil
    }
}
