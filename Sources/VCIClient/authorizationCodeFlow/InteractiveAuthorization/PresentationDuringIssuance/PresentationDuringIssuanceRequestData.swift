import Foundation

struct PresentationDuringIssuanceRequestData: AuthorizationRequestData {
    let ovpRequest: [String: Any]
    let authSession: String
    let iar: String
}
