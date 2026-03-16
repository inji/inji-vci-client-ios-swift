import Foundation

class NetworkRequestTimeoutException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-007",
            message: "Network request timeout - \(message ?? "")"
        )
    }
    
    public init(
            message: String?,
            serverErrorCode: String? = nil,
            serverErrorDescription: String? = nil,
            cause: Error? = nil
        ) {
            super.init(
                code: "VCI-007",
                message: "Network request timeout - \(message ?? "")",
                serverErrorCode: serverErrorCode,
                serverErrorDescription: serverErrorDescription,
                cause: cause
            )
        }
}
