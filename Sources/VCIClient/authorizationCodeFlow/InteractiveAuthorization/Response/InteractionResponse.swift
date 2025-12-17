import Foundation

class InteractionResponse {
    let status: String?
    let type: String?
    let authSession: String?

    init(
        status: String?,
        type: String?,
        authSession: String?
    ) throws {
        try Self.validateCommonFields(
            status: status,
            type: type,
            authSession: authSession
        )
        
        self.status = status
        self.type = type
        self.authSession = authSession
    }

    private static func validateCommonFields(
        status: String?,
        type: String?,
        authSession: String?
    ) throws {

        guard let status, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IllegalArgumentException("Missing or empty 'status' field")
        }

        if status == "require_interaction" {
            guard let type, !type.isEmpty else {
                throw IllegalArgumentException(
                    "'type' is required when status is 'require_interaction'"
                )
            }

            guard let authSession, !authSession.isEmpty else {
                throw IllegalArgumentException(
                    "'authSession' is required when status is 'require_interaction'"
                )
            }
        }
    }

    func validate() throws {
        fatalError("Subclasses must override validate()")
    }
}
