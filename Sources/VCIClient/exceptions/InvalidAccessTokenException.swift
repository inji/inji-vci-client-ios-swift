import Foundation

class InvalidAccessTokenException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-003",
            message: "Access token is invalid : \(message ?? "")"
        )
    }
    
    init(
        message: String?,
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-003",
            message: "Access token is invalid : \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
