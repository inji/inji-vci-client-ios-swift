import Foundation

protocol CredentialRequestFactoryProtocol {
    func createCredentialRequest(
        credentialFormat: CredentialFormat,
        accessToken: String,
        issuer: IssuerMetadata,
        proofJwt: Proof
    ) throws -> URLRequest
}

class CredentialRequestFactoryDraft13: CredentialRequestFactoryProtocol {
    static let shared = CredentialRequestFactoryDraft13()

    func createCredentialRequest(
        credentialFormat: CredentialFormat,
        accessToken: String,
        issuer: IssuerMetadata,
        proofJwt: Proof
    ) throws -> URLRequest {
        guard let proof = proofJwt as? JWTProof, !proof.jwt.isEmpty else {
            throw InvalidDataProvidedException("Proof object cannot be empty or invalid")
        }

        let credentialRequest: CredentialRequestProtocol

        switch credentialFormat {
        case .ldp_vc:
            credentialRequest = LdpVcCredentialRequestDraft13(
                accessToken: accessToken,
                issuerMetaData: issuer,
                proof: proof
            )
        case .mso_mdoc:
            credentialRequest = MsoMdocCredentialRequestDraft13(
                accessToken: accessToken,
                issuerMetaData: issuer,
                proof: proof
            )
        case .vc_sd_jwt, .dc_sd_jwt:
            credentialRequest = SdJwtCredentialRequestDraft13(
                accessToken: accessToken,
                issuerMetaData: issuer,
                proof: proof
            )
        }

        return try validateAndConstructCredentialRequest(credentialRequest: credentialRequest)
    }

    func validateAndConstructCredentialRequest(credentialRequest: CredentialRequestProtocol) throws -> URLRequest {
        let issuerMetadataValidatorResult = credentialRequest.validateIssuerMetadata()
        if issuerMetadataValidatorResult.isValid {
            return try credentialRequest.constructRequest()
        }
        throw InvalidDataProvidedException("invalid fields: \(issuerMetadataValidatorResult.invalidFields.joined(separator: ", "))")
    }
}
