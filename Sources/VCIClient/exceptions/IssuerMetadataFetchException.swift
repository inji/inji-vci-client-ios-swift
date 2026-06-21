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
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        super.init(
            code: "VCI-009",
            message: "Failed to fetch issuerMetadata: \(message ?? "")",
            issuerErrorCode: issuerErrorCode,
            issuerErrorDescription: issuerErrorDescription,
            cause: cause
        )
    }
}
