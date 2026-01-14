import Foundation

extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    init? (base64URLEncodedString: String) throws {
        let base64URLPayload = base64URLEncodedString.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddedPayload = base64URLPayload.padding(toLength: ((base64URLPayload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        self.init(base64Encoded: paddedPayload)
    }
}
