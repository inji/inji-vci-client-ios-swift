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
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-003",
            message: "Access token is invalid : \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
