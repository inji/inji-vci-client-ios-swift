import Foundation
import OpenID4VP
import OpenID4VPBridge

class PresentationDuringIssuanceAuthorizationMethodService: AuthorizationMethodService {
    private let selectCredentialsForPresentation: SelectCredentialsForPresentationCallback
    private let signVerifiablePresentation: SignVerifiablePresentationCallback
    private let openId4vp: OpenID4VPInteracting
    private let networkManager: NetworkManager
    private let ldpVpSignatureSuite: String?

    init(
        selectCredentialsForPresentation: @escaping SelectCredentialsForPresentationCallback,
        signVerifiablePresentation: @escaping SignVerifiablePresentationCallback,
        signatureSuite: String? = nil,
        networkManager: NetworkManager = NetworkManager.shared,
        openId4vp: OpenID4VPInteracting? = nil
    ) {
        self.selectCredentialsForPresentation = selectCredentialsForPresentation
        self.signVerifiablePresentation = signVerifiablePresentation
        self.openId4vp = openId4vp ?? OpenID4VPInteraction(traceabilityId: Util.getTraceabilityId())
        self.networkManager = networkManager
        ldpVpSignatureSuite = signatureSuite
    }

    func type() -> String {
        return InteractionType.openId4VpPresentation.rawValue
    }

    func authorizeUser(requestData: AuthorizationRequestData) async throws -> AuthorizationResponse {
        guard let presentationRequestData = requestData as? PresentationDuringIssuanceRequestData else {
            throw InteractiveAuthorizationException(
                message: "Expected PresentationDuringIssuanceRequestData"
            )
        }

        let vpResponse: [String: Any]

        do {
            do {
                let vpRequest = try await validatePresentationRequest(request: presentationRequestData.ovpRequest)
                vpResponse = try await handlePresentation(vpRequest: vpRequest)
            } catch {
                Util.logWarning(
                    message: "Error during presentation handling: \(error.localizedDescription)",
                    className: "PresentationDuringIssuanceAuthorizationMethodService"
                )
                vpResponse = openId4vp.constructErrorInfo(exception: error)
            }

            return try await sendOVPAuthorizationResponseToIssuer(
                iar: presentationRequestData.iar,
                authSession: presentationRequestData.authSession,
                vpResponse: vpResponse
            )

        } catch let ex as InteractiveAuthorizationException {
            throw ex

        } catch let ex as VCIClientException {
            throw InteractiveAuthorizationException(
                message: "Error during presentation authorization: \(ex.message)",
                serverErrorCode: ex.serverErrorCode,
                serverErrorDescription: ex.serverErrorDescription,
                cause: ex
            )

        } catch {
            throw InteractiveAuthorizationException(
                message: "Unexpected error during presentation authorization: \(error.localizedDescription)",
                cause: error
            )
        }
    }

    private func validatePresentationRequest(request: [String: Any]) async throws -> AuthorizationRequest {
        return try await openId4vp.authenticateVerifier(authRequest: request, trustedVerifiers: [Verifier](), shouldValidateClient: false)
    }

    private func handlePresentation(vpRequest: AuthorizationRequest) async throws -> [String: Any] {
        let selectedCredentials: [String: [FormatType: [OpenID4VPAnyCodable]]] = try await selectCredentialsForPresentation(vpRequest)
        if selectedCredentials.isEmpty {
            throw AccessDenied(message: "No credentials selected by user", className: "PresentationDuringIssuanceAuthorizationMethodService")
        }

        let holderId: String? = extractHolderId(credentials: selectedCredentials)

        let flattenedFormatEntries: [(FormatType, [OpenID4VPAnyCodable])] = selectedCredentials.values.flatMap { formatMap in
            formatMap.map { ($0.key, $0.value) }
        }
        let hasLdpVc = flattenedFormatEntries.filter { formatType, _ in
            formatType == .ldp_vc
        }.count != 0
        if hasLdpVc && ldpVpSignatureSuite == nil {
            throw InteractiveAuthorizationException(message: "Missing signature suite for LDP VC")
        }

        let unsignedVpTokens: [UnsignedVPToken] = try await openId4vp.constructUnsignedVPToken(
            verifiableCredentials: selectedCredentials,
            holderId: holderId,
            ldpVpSignatureSuite: ldpVpSignatureSuite
        )
        let signedVpTokens: [VPTokenSigningResult] = try await signVerifiablePresentation(unsignedVpTokens)

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
        vpResponse: [String: Any]
    ) async throws -> AuthorizationResponse {
        let response: NetworkResponse

        do {
            let vpResponseData = try JSONSerialization.data(withJSONObject: vpResponse)
            guard let vpResponseString = String(data: vpResponseData, encoding: .utf8) else {
                throw InteractiveAuthorizationException(
                    message: "Failed to serialize VP response"
                )
            }

            response = try await networkManager.sendRequest(
                url: iar,
                method: .post,
                headers: ["Content-Type": ContentTypes.applicationFormUrlEncoded.rawValue],
                bodyParams: [
                    "openid4vp_response": vpResponseString,
                    "auth_session": authSession,
                ]
            )

        } catch let ex as InteractiveAuthorizationException {
            throw ex
        } catch let ex as VCIClientException {
            throw InteractiveAuthorizationException(
                message: "Error while posting VP response: \(ex.message)",
                serverErrorCode: ex.serverErrorCode,
                serverErrorDescription: ex.serverErrorDescription,
                cause: ex
            )

        } catch {
            throw InteractiveAuthorizationException(
                message: "Unexpected error while posting VP response: \(error.localizedDescription)",
                cause: error
            )
        }

        do {
            guard let data = response.body.data(using: .utf8) else {
                throw InteractiveAuthorizationException(
                    message: "Issuer response is not valid UTF-8"
                )
            }

            return try JSONDecoder().decode(AuthorizationResponse.self, from: data)

        } catch {
            throw InteractiveAuthorizationException(
                message: "Issuer response deserialization failed",
                cause: error
            )
        }
    }
}
