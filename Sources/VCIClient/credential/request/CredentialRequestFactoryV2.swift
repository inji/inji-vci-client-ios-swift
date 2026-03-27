import Foundation

class CredentialRequestFactoryV2 {
    func createCredentialRequest(
        credentialFormat: CredentialFormat,
        accessToken: String,
        issuer: IssuerMetadata,
        proofs: CredentialRequestProofs
    ) throws -> URLRequest {
        guard !proofs.isEmpty else {
            throw InvalidDataProvidedException("Proof collection cannot be empty")
        }

        var request = try makeBaseRequest(
            accessToken: accessToken,
            issuer: issuer
        )
        request.httpBody = try makeRequestBody(
            credentialFormat: credentialFormat,
            issuer: issuer,
            proofs: proofs
        )
        return request
    }

    func makeBaseRequest(
        accessToken: String,
        issuer: IssuerMetadata
    ) throws -> URLRequest {
        guard let url = URL(string: issuer.credentialEndpoint) else {
            throw DownloadFailedException("Invalid credential endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    func makeRequestBody(
        credentialFormat: CredentialFormat,
        issuer: IssuerMetadata,
        proofs: CredentialRequestProofs
    ) throws -> Data {
        let encoder = JSONEncoder()
        let payload = try makeNormalizedPayload(
            credentialFormat: credentialFormat,
            issuer: issuer
        )

        switch payload {
        case let .ldpVc(format, credentialDefinition):
            return try encoder.encode(
                LdpCredentialRequestBodyV2(
                    format: format,
                    credential_definition: credentialDefinition,
                    proofs: proofs
                )
            )

        case let .jwtVcJson(format, credentialDefinition):
            return try encoder.encode(
                JwtVcCredentialRequestBodyV2(
                    format: format,
                    credential_definition: credentialDefinition,
                    proofs: proofs
                )
            )

        case let .msoMdoc(format, doctype):
            return try encoder.encode(
                MsoMdocCredentialRequestBodyV2(
                    format: format,
                    proofs: proofs,
                    doctype: doctype
                )
            )

        case let .sdJwt(format, vct):
            return try encoder.encode(
                SdJwtVcCredentialRequestBodyV2(
                    format: format,
                    vct: vct,
                    proofs: proofs
                )
            )
        }
    }

    func makeNormalizedPayload(
        credentialFormat: CredentialFormat,
        issuer: IssuerMetadata
    ) throws -> CredentialRequestPayload {
        switch credentialFormat {
        case .ldp_vc:
            guard let credentialTypes = issuer.credentialType, !credentialTypes.isEmpty else {
                throw InvalidDataProvidedException("Credential type is missing in issuer metadata")
            }
            let definition = CredentialDefinition(
                context: issuer.context ?? ["https://www.w3.org/2018/credentials/v1"],
                type: credentialTypes
            )
            return .ldpVc(format: credentialFormat, credentialDefinition: definition)

        case .jwt_vc_json:
            guard let credentialTypes = issuer.credentialType, !credentialTypes.isEmpty else {
                throw InvalidDataProvidedException("Credential type is missing in issuer metadata")
            }
            return .jwtVcJson(
                format: credentialFormat,
                credentialDefinition: JwtCredentialDefinition(type: credentialTypes)
            )

        case .mso_mdoc:
            guard let doctype = issuer.doctype else {
                throw InvalidDataProvidedException("Missing doctype in issuer metadata")
            }
            return .msoMdoc(format: credentialFormat, doctype: doctype)

        case .vc_sd_jwt, .dc_sd_jwt:
            guard let vct = issuer.vct else {
                throw InvalidDataProvidedException("Missing 'vct' in issuer metadata")
            }
            return .sdJwt(format: credentialFormat, vct: vct)
        }
    }
}

enum CredentialRequestPayload {
    case ldpVc(format: CredentialFormat, credentialDefinition: CredentialDefinition)
    case jwtVcJson(format: CredentialFormat, credentialDefinition: JwtCredentialDefinition)
    case msoMdoc(format: CredentialFormat, doctype: String)
    case sdJwt(format: CredentialFormat, vct: String)
}

private struct JwtVcCredentialRequestBodyV2: Encodable {
    let format: CredentialFormat
    let credential_definition: JwtCredentialDefinition
    let proofs: CredentialRequestProofs
}

private struct LdpCredentialRequestBodyV2: Encodable {
    let format: CredentialFormat
    let credential_definition: CredentialDefinition
    let proofs: CredentialRequestProofs
}

private struct MsoMdocCredentialRequestBodyV2: Encodable {
    let format: CredentialFormat
    let proofs: CredentialRequestProofs
    let doctype: String
}

private struct SdJwtVcCredentialRequestBodyV2: Encodable {
    let format: CredentialFormat
    let vct: String
    let proofs: CredentialRequestProofs
}
