import Foundation

class InvalidDataProvidedException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-004",
            message: "Required details not provided : \(message ?? "")"
        )
    }
    
    init(
        message: String?,
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-004",
            message: "Required details not provided : \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
