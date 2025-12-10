import Foundation

struct PresentationAuthorizationRequestData: AuthorizationRequestData {
    let ovpRequest: [String: Any]
    let authSession: String?
    let iar: String
}
