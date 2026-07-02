import CryptoSwift
import Foundation
import JSONWebAlgorithms
import JSONWebKey

private let rsaKeySizeInBits = 2048

struct DPoPKeyMaterial {
    let signingKey: any KeyRepresentable
    let publicJWK: JWK
}

enum DPoPAlgorithm: String {
    case eddsa = "EdDSA"
    case es256k = "ES256K"
    case es256 = "ES256"
    case es384 = "ES384"
    case es512 = "ES512"
    case rs256 = "RS256"

    var signingAlgorithm: SigningAlgorithm {
        switch self {
        case .eddsa: return .EdDSA
        case .es256k: return .ES256K
        case .es256: return .ES256
        case .es384: return .ES384
        case .es512: return .ES512
        case .rs256: return .RS256
        }
    }

    func generateKeyMaterial() throws -> DPoPKeyMaterial {
        switch self {
        case .rs256:
            return try generateRsaKeyMaterial()
        default:
            return try generateEcKeyMaterial()
        }
    }

    private func generateEcKeyMaterial() throws -> DPoPKeyMaterial {
        let (keyType, curve) = ellipticParameters()
        guard let generator = JWK(keyType: keyType, curve: curve).keyGeneration else {
            throw VCIClientException(
                code: "VCI-011",
                message: "Unable to generate a DPoP key for algorithm \(rawValue)"
            )
        }
        let privateKey = try generator.generateKeyPairJWK(purpose: .signing)
        return DPoPKeyMaterial(
            signingKey: privateKey,
            publicJWK: DPoPAlgorithm.publicOnly(privateKey)
        )
    }

    private func generateRsaKeyMaterial() throws -> DPoPKeyMaterial {
        let privateKey = try CryptoSwift.RSA(keySize: rsaKeySizeInBits)
        let fullJWK = privateKey.jwkRepresentation
        guard let n = fullJWK.n, let e = fullJWK.e else {
            throw VCIClientException(code: "VCI-011", message: "Unable to extract RSA public key components")
        }
        let publicJWK = JWK(keyType: .rsa, e: e, n: n)
        return DPoPKeyMaterial(signingKey: privateKey, publicJWK: publicJWK)
    }

    private func ellipticParameters() -> (JWK.KeyType, JWK.CryptographicCurve) {
        switch self {
        case .eddsa: return (.octetKeyPair, .ed25519)
        case .es256k: return (.ellipticCurve, .secp256k1)
        case .es384: return (.ellipticCurve, .p384)
        case .es512: return (.ellipticCurve, .p521)
        default: return (.ellipticCurve, .p256)
        }
    }

    private static func publicOnly(_ jwk: JWK) -> JWK {
        JWK(keyType: jwk.keyType, curve: jwk.curve, x: jwk.x, y: jwk.y)
    }

    static func select(_ authorizationServerSupported: [String]?) throws -> DPoPAlgorithm {
        guard let supported = authorizationServerSupported, !supported.isEmpty else {
            return .rs256
        }
        let preferenceOrder: [DPoPAlgorithm] = [.eddsa, .es256k, .es256, .es384, .es512, .rs256]
        guard let match = preferenceOrder.first(where: { supported.contains($0.rawValue) }) else {
            let clientSupported = preferenceOrder.map(\.rawValue).joined(separator: ", ")
            throw VCIClientException(
                code: "VCI-012",
                message: "No supported DPoP algorithm found. AS supports: \(supported), " +
                         "client supports: [\(clientSupported)]"
            )
        }
        return match
    }
}
