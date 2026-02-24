import Foundation

class InvalidPublicKeyException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-005",
            message: "Invalid public key passed: \(message ?? "")"
        )
    }
    
    init(
        message: String?,
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-005",
            message: "Invalid public key passed: \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
