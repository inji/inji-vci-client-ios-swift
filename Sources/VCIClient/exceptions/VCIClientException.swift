import Foundation

public class VCIClientException: Error, LocalizedError {

    public let code: String
    public let message: String
    public let sourceErrorCode: String?
    public let serverErrorCode: String?
    public let serverErrorDescription: String?
    public let cause: Error?

    public init(code: String, message: String) {
        self.code = code
        self.message = message
        self.serverErrorCode = nil
        self.serverErrorDescription = nil
        self.cause = nil
        self.sourceErrorCode = nil

        Util.logError(
            message: "Exception occurred with code: \(code), message: \(message)",
            className: "VCIClientException"
        )
    }

    public init(
        code: String,
        message: String,
        serverErrorCode: String? = nil,
        serverErrorDescription: String? = nil,
        cause: Error? = nil
    ) {
        self.code = code
        self.message = message
        self.serverErrorCode = serverErrorCode
        self.serverErrorDescription = serverErrorDescription
        self.cause = cause
        self.sourceErrorCode = VCIClientException.extractRootCode(from: cause)

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
