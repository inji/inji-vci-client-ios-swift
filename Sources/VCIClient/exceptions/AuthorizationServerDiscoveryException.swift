import Foundation

class AuthorizationServerDiscoveryException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-001",
            message: "Failed to discover authorization server: \(message ?? "")"
        )
    }

    init(
        message: String?,
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-001",
            message: "Failed to discover authorization server: \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
