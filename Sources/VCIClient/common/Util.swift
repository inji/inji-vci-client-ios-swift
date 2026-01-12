import Foundation

class Util {
    private static var traceabilityId: String?
    
    static func getLogTag(className: String, traceabilityId: String? = nil) -> String {
        if let traceId = traceabilityId {
            self.traceabilityId = traceId
        }
        return "INJI-VCI-Client : \(className) | traceID \(Self.getTraceabilityId())"
    }
    
    static func getTraceabilityId() -> String {
        return traceabilityId ?? "VciClient"
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
    error as? VCIClientException
        ?? VCIClientException(code: "VCI-010", message: "Unknown exception occurred")
}
