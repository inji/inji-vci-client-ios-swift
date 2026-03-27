import Foundation

public struct CredentialRequestProofs: Encodable {
    public let jwt: [String]?

    public init(jwt: [String]? = nil) {
        self.jwt = jwt
    }

    var firstJwtProof: String? {
        jwt?.first
    }

    var isEmpty: Bool {
        (jwt?.isEmpty ?? true)
    }
}
