import Foundation

class CredentialOfferFetchFailedException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-008",
            message: "Failed to fetch credential offer: \(message ?? "")"
        )
    }
    
    init(
        _ message: String?,
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-008",
            message: "Failed to fetch credential offer: \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
