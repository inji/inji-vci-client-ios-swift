import Foundation
import os

class Util {
    private static var traceabilityId: String?
    
    private static var logger: Logger?
    
    static func getLogTag(className: String, traceabilityId: String? = nil) -> String {
        if let traceId = traceabilityId {
            self.traceabilityId = traceId
        }
        return "INJI-VCI-Client : \(className) | traceID \(Self.getTraceabilityId())"
    }
    
    static func getTraceabilityId() -> String {
        return traceabilityId ?? "VciClient"
    }
    
    fileprivate static func getLogger(_ className: String) {
        if logger == nil {
            logger = Logger(subsystem: "INJI-VCI-Client", category: "SDK")
        }
    }
    
    static func logError(message: String, className: String) {
        getLogger(className)
        
        logger?.error("\(Self.getLogTag(className: className)): \(message, privacy: .public)")
    }
    
    static func logWarning(message: String, className: String) {
        getLogger(className)
        
        logger?.warning("\(Self.getLogTag(className: className)): \(message, privacy: .public)")
    }
    
    static func convertToAnyCodable(dict: [String: Any]) -> [String: AnyCodable] {
        var result: [String: AnyCodable] = [:]
        
        for (key, value) in dict {
            result[key] = AnyCodable(value)
        }
        
        return result
    }
}

func mapToVciClientException(_ error: Error) -> VCIClientException {
    
    if let vciError = error as? VCIClientException {
        return VCIClientException(
            code: "VCI-010",
            message: vciError.message,
            issuerErrorCode: vciError.issuerErrorCode, issuerErrorDescription: vciError.issuerErrorDescription, cause: vciError.cause ?? vciError
        )
    }

    return VCIClientException(
        code: "VCI-010",
        message: "Unknown Exception - \(error.localizedDescription)",
        issuerErrorCode: nil, issuerErrorDescription: nil, cause: error
    )
}
