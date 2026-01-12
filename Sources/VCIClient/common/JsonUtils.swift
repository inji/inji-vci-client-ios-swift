import Foundation

enum JsonUtils {    
    static func encode<T: Encodable>(_ data: T, empty: String = "{}") -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            let jsonData = try encoder.encode(data)
            return String(decoding: jsonData, as: UTF8.self)
        } catch {
            return empty
        }
    }
    
    static func deserialize<T: Decodable>(_ json: String, as type: T.Type) throws -> T? {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        
        return try decoder.decode(T.self, from: data)
    }
    
    static func toMap(_ json: String) -> [String: Any] {
        guard !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = json.data(using: .utf8) else {
            return [:]
        }
        
        do {
            let jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
            return jsonObj as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
    
    static func toJsonString<T : Encodable>(_ clazzData: T) -> String? {
        if let data = try? JSONEncoder().encode(clazzData),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        } else {
            return nil
        }
        
    }
}
