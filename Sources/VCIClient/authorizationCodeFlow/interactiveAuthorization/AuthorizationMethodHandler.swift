import Foundation

protocol AuthorizationMethodHandler {
    func type() -> String
    func authorizeUser(requestData: AuthorizationRequestData) async throws -> AuthorizationResponse
}
