import Foundation

public protocol CredentialRequestFactoryProtocol {
    func createCredentialRequest(
        credentialFormat: CredentialFormat,
        accessToken: String,
        issuer: IssuerMetadata,
        proofJwt: Proof) throws -> URLRequest
}

class CredentialRequestFactory: CredentialRequestFactoryProtocol {
    static let shared = CredentialRequestFactory()
    func createCredentialRequest(
        credentialFormat: CredentialFormat,
        accessToken: String,
        issuer: IssuerMetadata,
        proofJwt: Proof) throws -> URLRequest {
            switch credentialFormat {
            case .ldp_vc:
                return try validateAndConstructCredentialRequest(credentialRequest: LdpVcCredentialRequest(
                    accessToken: accessToken,
                    issuerMetaData: issuer,
                    proof: proofJwt as? JWTProof ?? JWTProof(jwt: "")))
                    
            case .jwt_vc, .jwt_vc_json:
                 return try validateAndConstructCredentialRequest(credentialRequest: JwtVcCredentialRequest(
                    accessToken: accessToken,
                    issuerMetaData: issuer,
                    proof: proofJwt as? JWTProof ?? JWTProof(jwt: "")))
            case .mso_mdoc:
                return try validateAndConstructCredentialRequest(credentialRequest: MsoMdocVcCredentialRequest(accessToken: accessToken,
                                                                                                               issuerMetaData: issuer,
                                                                                                               proof: proofJwt as? JWTProof ?? JWTProof(jwt: "")))
            case .vc_sd_jwt,.dc_sd_jwt:
                return try validateAndConstructCredentialRequest(credentialRequest: SdJwtCredentialRequest(accessToken: accessToken,
                                                                                                           issuerMetaData: issuer,
                                                                                                           proof: proofJwt as? JWTProof ?? JWTProof(jwt: "")))
            }
    }

    func validateAndConstructCredentialRequest(credentialRequest: CredentialRequestProtocol) throws -> URLRequest {
        let issuerMetadataValidatorResult = credentialRequest.validateIssuerMetadata()
        if issuerMetadataValidatorResult.isValid {
            return try credentialRequest.constructRequest()
        }
        throw InvalidDataProvidedException("invalid fields: \(issuerMetadataValidatorResult.invalidFields.joined())")
    }
}
