import Foundation

public class VCIClientException: Error, LocalizedError {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
        Util.logError(message: "Exception occurred with code: \(code), message: \(message)", className: "VCIClientException")
    }

    public var errorDescription: String? {
        return message
    }
}
