import Foundation

class IllegalArgumentException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-012",
            message: message ?? "An illegal argument was provided."
        )
    }
    
    init(
        message: String?,
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-012",
            message: message ?? "An illegal argument was provided.",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
