import Foundation

protocol AuthorizationMethodHandler {
    func type() -> String
    func authorizeUser(requestData: AuthorizationRequestData) async throws -> AuthorizationResponse
}

//TODO: move to separate files

protocol AuthorizationRequestData {}

struct AuthorizationResponse: Codable {
    let authorizationCode: String?
    let status: String?
    let error: String?
    let errorDescription: String?
    let authSession: String?

    enum CodingKeys: String, CodingKey {
        case authorizationCode = "authorization_code"
        case status
        case error
        case errorDescription = "error_description"
        case authSession = "auth_session"
    }
}

struct PresentationAuthorizationRequestData: AuthorizationRequestData {
    let ovpRequest: [String: Any]
    let authSession: String?
    let iar: String
}
