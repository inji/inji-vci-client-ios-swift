import Foundation

class DownloadFailedException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-002",
            message: "Failed to download Credential: \(message ?? "")"
        )
    }
    
    init(
        message: String?,
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-002",
            message: "Failed to download Credential: \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
