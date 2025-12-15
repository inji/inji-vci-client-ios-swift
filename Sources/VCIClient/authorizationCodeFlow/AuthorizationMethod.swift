import Foundation
import OpenID4VP

enum AuthorizationMethod {
    case redirectToWeb(
        openWebPage: OpenWebPageCallback
    )

    case presentationDuringIssuance(
        selectCredentialsForPresentation: CredentialSelectionCallback,
        signVerifiablePresentation: SignPresentationCallback
    )

    var type: InteractionType {
        switch self {
        case .redirectToWeb:
            return .redirectToWeb
        case .presentationDuringIssuance:
            return .openId4VpPresentation
        }
    }
}


typealias OpenWebPageCallback = (_ url: String) -> [String: Any]

typealias CredentialSelectionCallback =
    (_ request: AuthorizationRequest) async throws -> [String: [FormatType: [Any]]]

typealias SignPresentationCallback =
    (_ payload: [FormatType: UnsignedVPToken]) async throws -> [FormatType: VPTokenSigningResult]
