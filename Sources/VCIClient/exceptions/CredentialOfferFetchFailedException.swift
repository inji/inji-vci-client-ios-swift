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
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-008",
            message: "Failed to fetch credential offer: \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
