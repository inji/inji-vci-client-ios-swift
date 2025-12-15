import Foundation

class InteractiveAuthorizationException: VCIClientException {
    //TODO: changed signature of init to match VCIClientException
    // TODO: check if its required for error code to be customizable
    override init(code:String = "VCI-011", message: String?) {
        super.init(
            code: code,
            message: "Failed to download Credential: \(message ?? "")"
        )
    }
}
