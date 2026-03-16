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
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-012",
            message: message ?? "An illegal argument was provided.",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
