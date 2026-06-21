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
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-005",
            message: "Invalid public key passed: \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
