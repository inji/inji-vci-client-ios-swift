import Foundation

protocol AuthorizationMethodService {
    func type() -> String
    func authorizeUser(requestData: AuthorizationRequestData, networkTimeout: Int64) async throws -> AuthorizationResponse
}
