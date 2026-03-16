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
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-002",
            message: "Failed to download Credential: \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
