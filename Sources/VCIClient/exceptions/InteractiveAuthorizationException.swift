import Foundation

class InteractiveAuthorizationException: VCIClientException {
    override init(code:String = "VCI-011", message: String?) {
        Util.logError(message: "Error occurring during interaction flow - \(message ?? "")", className: "InteractiveAuthorizationException")
        super.init(
            code: code,
            message: "Failed to authorize via interaction: \(message ?? "")"
        )
    }
    init(
        message: String?,
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-011",
            message: "Failed to authorize via interaction: \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
