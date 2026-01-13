import Foundation

protocol AuthorizationMethodService {
    func type() -> String
    func authorizeUser(requestData: AuthorizationRequestData) async throws -> AuthorizationResponse
}
