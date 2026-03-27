import Foundation

/// Identifies which version of the OpenID for Verifiable Credential Issuance spec
/// an issuer is running, as detected from its metadata.
public enum OID4VCIVersion: String, Codable, Equatable {
    /// OpenID for VCI 1.0 final spec.
    /// Detected from issuer metadata hints, with v1 used as the fallback when inconclusive.
    case v1

    /// OpenID for VCI Draft 13.
    /// Detected from legacy issuer metadata hints such as `credentials_supported`.
    case draft13
}
