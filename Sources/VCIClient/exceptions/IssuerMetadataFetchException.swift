import Foundation

class IssuerMetadataFetchException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-009",
            message: "Failed to fetch issuerMetadata: \(message ?? "")"
        )
    }

    init(
        _ message: String?,
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-009",
            message: "Failed to fetch issuerMetadata: \(message ?? "")",
            serverErrorCode: serverErrorCode,
            serverErrorDescription: serverErrorDescription,
            cause: cause
        )
    }
}
