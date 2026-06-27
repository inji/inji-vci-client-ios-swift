import CryptoKit
import Foundation

/// Owns the DPoP mechanism for a single issuance flow as described in the DPoP ADR (RFC 9449).
///
/// A fresh ephemeral EC key pair is generated in memory for the flow and reused to sign every
/// proof - the `dpop_jkt` in the authorization URL, the token-endpoint proof, and the
/// credential-endpoint proof. The key never leaves the library and is never persisted.
class DPoPManager {
    private enum KeyPair {
        case p256(P256.Signing.PrivateKey)
        case p384(P384.Signing.PrivateKey)
        case p521(P521.Signing.PrivateKey)

        var publicKeyRawRepresentation: Data {
            switch self {
            case let .p256(key): return key.publicKey.rawRepresentation
            case let .p384(key): return key.publicKey.rawRepresentation
            case let .p521(key): return key.publicKey.rawRepresentation
            }
        }

        func signature(for data: Data) throws -> Data {
            switch self {
            case let .p256(key): return try key.signature(for: data).rawRepresentation
            case let .p384(key): return try key.signature(for: data).rawRepresentation
            case let .p521(key): return try key.signature(for: data).rawRepresentation
            }
        }
    }

    private struct Session {
        let keyPair: KeyPair
        let algorithm: DPoPAlgorithm
        let tokenEndpoint: String
    }

    private var session: Session?

    var isInitialized: Bool { session != nil }

    func initialize(tokenEndpoint: String, authorizationServerSupportedAlgorithms: [String]?) {
        guard session == nil else { return }
        let algorithm = DPoPAlgorithm.select(authorizationServerSupportedAlgorithms)
        let keyPair: KeyPair
        switch algorithm {
        case .es256: keyPair = .p256(P256.Signing.PrivateKey())
        case .es384: keyPair = .p384(P384.Signing.PrivateKey())
        case .es512: keyPair = .p521(P521.Signing.PrivateKey())
        }
        session = Session(
            keyPair: keyPair,
            algorithm: algorithm,
            tokenEndpoint: DPoPManager.normalizeHtu(tokenEndpoint)
        )
    }

    func reset() {
        session = nil
    }

    func jwkThumbprint() throws -> String {
        let activeSession = try requireSession()
        let coordinates = DPoPManager.coordinates(activeSession.keyPair)
        let canonical: [String: String] = [
            "crv": activeSession.algorithm.curveName,
            "kty": "EC",
            "x": coordinates.x,
            "y": coordinates.y,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: canonical,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return Data(SHA256.hash(data: data)).base64URLEncodedString()
    }

    func generateTokenProof(nonce: String? = nil) throws -> String {
        let activeSession = try requireSession()
        return try buildProof(
            activeSession,
            htu: activeSession.tokenEndpoint,
            nonce: nonce,
            accessToken: nil
        )
    }

    func generateCredentialProof(
        credentialEndpoint: String,
        accessToken: String,
        nonce: String? = nil
    ) throws -> String {
        let activeSession = try requireSession()
        return try buildProof(
            activeSession,
            htu: DPoPManager.normalizeHtu(credentialEndpoint),
            nonce: nonce,
            accessToken: accessToken
        )
    }

    private func buildProof(
        _ activeSession: Session,
        htu: String,
        nonce: String?,
        accessToken: String?
    ) throws -> String {
        let coordinates = DPoPManager.coordinates(activeSession.keyPair)
        let header: [String: Any] = [
            "typ": DPoPConstants.dpopJwtType,
            "alg": activeSession.algorithm.rawValue,
            "jwk": [
                "kty": "EC",
                "crv": activeSession.algorithm.curveName,
                "x": coordinates.x,
                "y": coordinates.y,
            ],
        ]

        let issuedAt = Int(Date().timeIntervalSince1970)
        var payload: [String: Any] = [
            "jti": UUID().uuidString,
            "htm": DPoPConstants.httpMethodPost,
            "htu": htu,
            "iat": issuedAt,
            "exp": issuedAt + Int(DPoPConstants.proofLifetimeSeconds),
        ]
        if let nonce = nonce {
            payload["nonce"] = nonce
        }
        if let accessToken = accessToken {
            payload["ath"] = DPoPManager.accessTokenHash(accessToken)
        }

        let signingInput = try DPoPManager.base64URLJSON(header)
            + "." + DPoPManager.base64URLJSON(payload)
        let signature = try activeSession.keyPair.signature(for: Data(signingInput.utf8))
        return signingInput + "." + signature.base64URLEncodedString()
    }

    private func requireSession() throws -> Session {
        guard let session = session else {
            throw VCIClientException(
                code: "VCI-011",
                message: "DPoP session is not initialized for the current flow"
            )
        }
        return session
    }

    private static func coordinates(_ keyPair: KeyPair) -> (x: String, y: String) {
        let raw = keyPair.publicKeyRawRepresentation
        let half = raw.count / 2
        return (
            raw.prefix(half).base64URLEncodedString(),
            raw.suffix(half).base64URLEncodedString()
        )
    }

    private static func accessTokenHash(_ accessToken: String) -> String {
        Data(SHA256.hash(data: Data(accessToken.utf8))).base64URLEncodedString()
    }

    private static func base64URLJSON(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return data.base64URLEncodedString()
    }

    private static func normalizeHtu(_ endpoint: String) -> String {
        guard var components = URLComponents(string: endpoint) else { return endpoint }
        components.query = nil
        components.fragment = nil
        return components.string ?? endpoint
    }
}
