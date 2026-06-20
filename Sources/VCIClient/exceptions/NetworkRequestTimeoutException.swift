import Foundation

class NetworkRequestTimeoutException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-007",
            message: "Network request timeout - \(message ?? "")"
        )
    }
    
    init(
            message: String?,
            issuerErrorCode: String? = nil,
            issuerErrorDescription: String? = nil,
            cause: Error? = nil
        ) {
            super.init(
                code: "VCI-007",
                message: "Network request timeout - \(message ?? "")",
                issuerErrorCode: issuerErrorCode,
                issuerErrorDescription: issuerErrorDescription,
                cause: cause
            )
        }
}
