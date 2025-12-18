import Foundation

class InteractiveAuthorizationException: VCIClientException {
    override init(code:String = "VCI-011", message: String?) {
        print("Error occuring during interaction flow - \(message ?? "")")
        super.init(
            code: code,
            message: "Failed to authorize via interaction: \(message ?? "")"
        )
    }
}
