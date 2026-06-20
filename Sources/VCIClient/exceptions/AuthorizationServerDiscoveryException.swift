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
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-001",
            message: "Failed to discover authorization server: \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
