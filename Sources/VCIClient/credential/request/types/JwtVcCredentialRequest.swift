import Foundation

class JwtVcCredentialRequest: CredentialRequestProtocol {
    let accessToken: String
    let issuerMetaData: IssuerMetadata
    let proof: JWTProof

    required init(accessToken: String, issuerMetaData: IssuerMetadata, proof: JWTProof) {
        self.accessToken = accessToken
        self.issuerMetaData = issuerMetaData
        self.proof = proof
    }

    func validateIssuerMetadata() -> ValidatorResult {
        if issuerMetaData.credentialEndpoint.isEmpty {
             return ValidatorResult(isValid: false, message: "Invalid or missing credentialEndpoint in issuer metadata")
        }
        if issuerMetaData.credentialType == nil || issuerMetaData.credentialType?.isEmpty == true {
            return ValidatorResult(isValid: false, message: "Invalid or missing credentialType in issuer metadata")
        }
        return ValidatorResult(isValid: true)
    }

    func constructRequest() throws -> URLRequest {
        guard let url = URL(string: issuerMetaData.credentialEndpoint) else {
            throw DownloadFailedException("Invalid credential endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body = try generateRequestBody(proofJWT: proof, issuer: issuerMetaData)
        request.httpBody = body

        return request
    }

    private func generateRequestBody(proofJWT: JWTProof, issuer: IssuerMetadata) throws -> Data {
        let definition = CredentialDefinition(type: issuer.credentialType ?? [])
        let requestBody = JwtVcCredentialRequestBody(
            format: issuer.credentialFormat,
            credential_definition: definition,
            proof: proofJWT
        )

        do {
            return try JSONEncoder().encode(requestBody)
        } catch {
            throw DownloadFailedException("Failed to encode request body: \(error.localizedDescription)")
        }
    }
}

struct CredentialDefinition: Encodable {
    let type: [String]
}

struct JwtVcCredentialRequestBody: Encodable {
    let format: CredentialFormat
    let credential_definition: CredentialDefinition
    let proof: JWTProof
}
