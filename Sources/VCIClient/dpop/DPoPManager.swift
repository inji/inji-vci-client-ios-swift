import CryptoKit
import Foundation
import JSONWebAlgorithms
import JSONWebKey
import JSONWebSignature
import JSONWebToken


class DPoPManager {
    private struct Session {
        let signingKey: any KeyRepresentable
        let publicJWK: JWK
        let algorithm: DPoPAlgorithm
        let tokenEndpoint: String
    }

    private var session: Session?

    private var issuerNonce: String?

    var isInitialized: Bool { session != nil }

    func initialize(tokenEndpoint: String, authorizationServerSupportedAlgorithms: [String]?) throws {
        guard session == nil else { return }
        let algorithm = try DPoPAlgorithm.select(authorizationServerSupportedAlgorithms)
        let material = try algorithm.generateKeyMaterial()
        session = Session(
            signingKey: material.signingKey,
            publicJWK: material.publicJWK,
            algorithm: algorithm,
            tokenEndpoint: DPoPManager.normalizeHtu(tokenEndpoint)
        )
    }

    func reset() {
        session = nil
        issuerNonce = nil
    }

    func updateNonce(_ nonce: String?) {
        if let nonce = nonce, !nonce.trimmingCharacters(in: .whitespaces).isEmpty {
            issuerNonce = nonce
        }
    }

    func jwkThumbprint() throws -> String {
        try DPoPManager.thumbprint(of: requireSession().publicJWK)
    }

    func generateTokenProof(nonce: String? = nil) throws -> String {
        let activeSession = try requireSession()
        return try buildProof(activeSession, htu: activeSession.tokenEndpoint, nonce: nonce, accessToken: nil)
    }

    func generateCredentialProof(
        credentialEndpoint: String,
        accessToken: String,
        nonce: String? = nil
    ) throws -> String {
        let activeSession = try requireSession()
        updateNonce(nonce)
        return try buildProof(
            activeSession,
            htu: DPoPManager.normalizeHtu(credentialEndpoint),
            nonce: issuerNonce,
            accessToken: accessToken
        )
    }

    private func buildProof(
        _ activeSession: Session,
        htu: String,
        nonce: String?,
        accessToken: String?
    ) throws -> String {
        var header = DefaultJWSHeaderImpl(algorithm: activeSession.algorithm.signingAlgorithm)
        header.type = Constants.dpopJwtType
        header.jwk = activeSession.publicJWK

        let issuedAt = Int(Date().timeIntervalSince1970)
        let claims = DPoPProofClaims(
            jti: UUID().uuidString,
            htm: Constants.httpMethodPost,
            htu: htu,
            iat: issuedAt,
            exp: issuedAt + Int(Constants.dpopProofLifetimeSeconds),
            nonce: nonce,
            ath: accessToken.map { DPoPManager.accessTokenHash($0) }
        )

        return try JWT.signed(
            payload: claims,
            protectedHeader: header,
            key: activeSession.signingKey
        ).jwtString
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

    private static func accessTokenHash(_ accessToken: String) -> String {
        // RFC 9449 §4.2: hash the ASCII encoding of the access token
        let tokenData = accessToken.data(using: .ascii) ?? Data(accessToken.utf8)
        return Data(SHA256.hash(data: tokenData)).base64URLEncodedString()
    }

    private static func thumbprint(of jwk: JWK) throws -> String {
        let members: [String: String]
        switch jwk.keyType {
        case .ellipticCurve:
            guard let curve = jwk.curve?.rawValue, let x = jwk.x, let y = jwk.y else {
                throw VCIClientException(code: "VCI-011", message: "Incomplete EC JWK for thumbprint")
            }
            members = ["crv": curve, "kty": jwk.keyType.rawValue, "x": x.base64URLEncodedString(), "y": y.base64URLEncodedString()]
        case .octetKeyPair:
            guard let curve = jwk.curve?.rawValue, let x = jwk.x else {
                throw VCIClientException(code: "VCI-011", message: "Incomplete OKP JWK for thumbprint")
            }
            members = ["crv": curve, "kty": jwk.keyType.rawValue, "x": x.base64URLEncodedString()]
        case .rsa:
            guard let n = jwk.n, let e = jwk.e else {
                throw VCIClientException(code: "VCI-011", message: "Incomplete RSA JWK for thumbprint")
            }
            members = ["e": e.base64URLEncodedString(), "kty": jwk.keyType.rawValue, "n": n.base64URLEncodedString()]
        default:
            throw VCIClientException(code: "VCI-011", message: "Unsupported JWK type for thumbprint")
        }
        let canonical = try JSONSerialization.data(
            withJSONObject: members,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return Data(SHA256.hash(data: canonical)).base64URLEncodedString()
    }

    private static func normalizeHtu(_ endpoint: String) -> String {
        guard var components = URLComponents(string: endpoint) else { return endpoint }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        if components.path.isEmpty {
            components.path = "/"
        }
        if components.scheme == "https", components.port == 443 {
            components.port = nil
        }
        if components.scheme == "http", components.port == 80 {
            components.port = nil
        }
        components.query = nil
        components.fragment = nil
        return components.string ?? endpoint
    }
}

private struct DPoPProofClaims: Codable {
    let jti: String
    let htm: String
    let htu: String
    let iat: Int
    let exp: Int
    let nonce: String?
    let ath: String?
}
