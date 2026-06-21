import Foundation

class NetworkRequestFailedException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-006",
            message: "Network request failed, details - \(message ?? "")"
        )
    }

    init(
        message: String?,
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-006",
            message: "Network request failed, details - \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
