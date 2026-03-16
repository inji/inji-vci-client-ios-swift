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
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-004",
            message: "Required details not provided : \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
