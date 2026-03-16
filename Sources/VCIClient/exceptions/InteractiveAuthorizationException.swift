import Foundation

class InteractiveAuthorizationException: VCIClientException {
    override init(code:String = "VCI-011", message: String?) {
        print("Error occuring during interaction flow - \(message ?? "")")
        super.init(
            code: code,
            message: "Failed to authorize via interaction: \(message ?? "")"
        )
    }
    init(
        message: String?,
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-011",
            message: "Failed to authorize via interaction: \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
