import Foundation

struct InteractiveAuthorizationException: VCIClientException {
    init(code:String, message: String?) {
        super.init(
            code: code,
            message: "Failed to download Credential: \(message ?? "")"
        )
    }
}
