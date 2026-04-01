import Foundation

class LdpVcCredentialRequestDraft13: CredentialRequestProtocol {
    let accessToken: String
    let issuerMetaData: IssuerMetadata
    let proof: JWTProof
    required init(accessToken: String, issuerMetaData: IssuerMetadata, proof: JWTProof) {
        self.accessToken = accessToken
        self.issuerMetaData = issuerMetaData
        self.proof = proof
    }

    func validateIssuerMetadata() -> ValidatorResult {
        let validatorResult = ValidatorResult()
        if issuerMetaData.credentialType == nil || issuerMetaData.credentialType?.count == 0 {
            validatorResult.addInvalidField("credentialType")
        }
        return validatorResult
    }

    func constructRequest() throws -> URLRequest {
        var request = URLRequest(url: URL(string: issuerMetaData.credentialEndpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        guard let requestBody = try generateRequestBody(proofJWT: proof, issuer: issuerMetaData) else {
            throw DownloadFailedException("")
        }

        request.httpBody = requestBody

        return request
    }

    func generateRequestBody(proofJWT: JWTProof, issuer: IssuerMetadata) throws -> Data? {
        let credentialDefinition = CredentialDefinition(context: getIssuerContext(issuer: issuer), type: issuer.credentialType!)

        let credentialRequestBody = LdpCredentialRequestBodyDraft13(
            format: issuer.credentialFormat,
            credential_definition: credentialDefinition,
            proof: proofJWT
        )

        do {
            let jsonData = try JSONEncoder().encode(credentialRequestBody)
            return jsonData
        } catch {
            throw DownloadFailedException("")
        }
    }

    private func getIssuerContext(issuer: IssuerMetadata) -> [String] {
        if issuer.context != nil {
            return issuer.context!
        }
        return ["https://www.w3.org/2018/credentials/v1"]
    }
}

struct LdpCredentialRequestBodyDraft13: Encodable {
    let format: CredentialFormat
    let credential_definition: CredentialDefinition
    let proof: JWTProof

    init(format: CredentialFormat, credential_definition: CredentialDefinition, proof: JWTProof) {
        self.format = format
        self.credential_definition = credential_definition
        self.proof = proof
    }
}



struct CredentialDefinition: Codable {
    let context: [String]?
    let type: [String]

    private enum CodingKeys: String, CodingKey {
        case context = "@context"
        case type
    }

    init(context: [String]? = ["https://www.w3.org/2018/credentials/v1"], type: [String]) {
        self.context = context
        self.type = type
    }
}
