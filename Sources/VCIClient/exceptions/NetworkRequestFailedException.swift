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
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-006",
            message: "Network request failed, details - \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
