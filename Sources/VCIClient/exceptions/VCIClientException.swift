import Foundation

public class VCIClientException: Error, LocalizedError {

    public let code: String
    public let message: String
    public let issuerErrorCode: String?
    public let issuerErrorDescription: String?
    public let cause: Error?

    public init(code: String, message: String) {
        self.code = code
        self.message = message
        self.issuerErrorCode = nil
        self.issuerErrorDescription = nil
        self.cause = nil

        Util.logError(
            message: "Exception occurred with code: \(code), message: \(message)",
            className: "VCIClientException"
        )
    }

    public init(
        code: String,
        message: String,
        issuerErrorCode: String? = nil,
        issuerErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        self.code = VCIClientException.extractRootCode(from: cause) ?? code
        self.message = message
        self.issuerErrorCode = issuerErrorCode
        self.issuerErrorDescription = issuerErrorDescription
        self.cause = cause

        Util.logError(
            message: "Exception occurred with code: \(code), message: \(message)",
            className: "VCIClientException"
        )
    }

    public var errorDescription: String? {
        return message
    }


    private static func extractRootCode(from cause: Error?) -> String? {
        var current = cause
        var lastCode: String?

        while let error = current {
            if let vciError = error as? VCIClientException {
                lastCode = vciError.code
                current = vciError.cause
            } else {
                break
            }
        }

        return lastCode
    }
}
