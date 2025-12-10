import Foundation

public class VCIClientException: Error, LocalizedError {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
        print("Exception occurred with code: \(code), message: \(message)")
    }

    public var errorDescription: String? {
        return message
    }
}
