import Foundation
import OpenID4VP
import OpenID4VPBridge

public enum AuthorizationMethod {
    case redirectToWeb(
        openWebPage: OpenWebPageCallback
    )

    case presentationDuringIssuance(
        jsonLdCanonicalizer: JsonLdCanonicalizerCallback? = nil,
        selectCredentialsForPresentation: SelectCredentialsForPresentationCallback,
        signVerifiablePresentation: SignVerifiablePresentationCallback
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
