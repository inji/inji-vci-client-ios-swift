import Foundation

extension String? {
    func isBlank() -> Bool {
        return self == nil || self!.replacingOccurrences(of: " ", with: "").count == 0
    }
}

extension String {
    func formURLEncoded() -> String {
        let allowed = CharacterSet.urlQueryAllowed
            .subtracting(CharacterSet(charactersIn: "+&="))
        
        return self.addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
