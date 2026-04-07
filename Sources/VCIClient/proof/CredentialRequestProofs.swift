import Foundation

public struct CredentialRequestProofs: Encodable {
    public let proofType: String
    public let proofs: [String]

    public init(proofType: String = "jwt", proofs: [String]) {
        self.proofType = proofType
        self.proofs = proofs
    }

    var firstProof: String? {
        proofs.first
    }

    var isEmpty: Bool {
        proofs.isEmpty
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(proofs, forKey: DynamicCodingKey(stringValue: proofType))
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
