import Foundation

public protocol CredentialRequestFactoryProtocol {
    func createCredentialRequest(
        credentialFormat: CredentialFormat,
        accessToken: String,
        issuer: IssuerMetadata,
        proofJwt: Proof
    ) throws -> URLRequest
}

class CredentialRequestFactory: CredentialRequestFactoryProtocol {
    static let shared = CredentialRequestFactory()

    private let factoryV2: CredentialRequestFactoryV2

    init(factoryV2: CredentialRequestFactoryV2 = CredentialRequestFactoryV2()) {
        self.factoryV2 = factoryV2
    }

    func createCredentialRequest(
        credentialFormat: CredentialFormat,
        accessToken: String,
        issuer: IssuerMetadata,
        proofJwt: Proof
    ) throws -> URLRequest {
        guard let proof = proofJwt as? JWTProof, !proof.jwt.isEmpty else {
            throw InvalidDataProvidedException("Proof object cannot be empty or invalid")
        }

        var request = try factoryV2.makeBaseRequest(
            accessToken: accessToken,
            issuer: issuer
        )
        request.httpBody = try makeDraft13RequestBody(
            credentialFormat: credentialFormat,
            issuer: issuer,
            proof: proof
        )
        return request
    }

    func makeDraft13RequestBody(
        credentialFormat: CredentialFormat,
        issuer: IssuerMetadata,
        proof: JWTProof
    ) throws -> Data {
        let payload = try factoryV2.makeNormalizedPayload(
            credentialFormat: credentialFormat,
            issuer: issuer
        )
        let encoder = JSONEncoder()

        switch payload {
        case let .ldpVc(format, credentialDefinition):
            return try encoder.encode(
                LdpCredentialRequestBodyDraft13(
                    format: format,
                    credential_definition: credentialDefinition,
                    proof: proof
                )
            )

        case let .jwtVcJson(format, credentialDefinition):
            return try encoder.encode(
                JwtVcCredentialRequestBodyDraft13(
                    format: format,
                    credential_definition: credentialDefinition,
                    proof: proof
                )
            )

        case let .msoMdoc(format, doctype):
            return try encoder.encode(
                MsoMdocCredentialRequestBodyDraft13(
                    format: format,
                    doctype: doctype,
                    proof: proof
                )
            )

        case let .sdJwt(format, vct):
            return try encoder.encode(
                SdJwtVcCredentialRequestBodyDraft13(
                    format: format,
                    vct: vct,
                    proof: proof
                )
            )
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

private struct JwtVcCredentialRequestBodyDraft13: Encodable {
    let format: CredentialFormat
    let credential_definition: JwtCredentialDefinition
    let proof: JWTProof
}

private struct LdpCredentialRequestBodyDraft13: Encodable {
    let format: CredentialFormat
    let credential_definition: CredentialDefinition
    let proof: JWTProof
}

private struct MsoMdocCredentialRequestBodyDraft13: Encodable {
    let format: CredentialFormat
    let doctype: String
    let proof: JWTProof
}

private struct SdJwtVcCredentialRequestBodyDraft13: Encodable {
    let format: CredentialFormat
    let vct: String
    let proof: JWTProof
}
