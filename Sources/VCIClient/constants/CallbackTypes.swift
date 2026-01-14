import OpenID4VP
import OpenID4VPBridge

public typealias AuthorizeUserCallback = (_ authorizationUrl: String) async throws -> String
public typealias TokenResponseCallback = (_ tokenRequest: TokenRequest) async throws -> TokenResponse
public typealias ProofJwtCallback = (
    _ credentialIssuer: String,
    _ cNonce: String?,
    _ proofSigningAlgorithmsSupported: [String]
) async throws -> String
public typealias CheckIssuerTrustCallback = ((_ credentialIssuer: String, _ issuerDisplay: [[String: Any]]) async throws -> Bool)?
public typealias TxCodeCallback = ((_ inputMode: String?, _ description: String?, _ length: Int?) async throws -> String)?

// Presentation During Issuance related Callbacks

public typealias SelectCredentialsForPresentationCallback = (_ ovpRequest: AuthorizationRequest) async throws -> [String : [FormatType : [OpenID4VPAnyCodable]]]
public typealias SignVerifiablePresentationCallback = (_ payload: [FormatType: UnsignedVPToken]) async throws -> [FormatType: VPTokenSigningResult]


// Redirect To Web related Callbacks

public typealias OpenWebPageCallback = (_ url: String) async throws -> [String: Any]
