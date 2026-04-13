import Foundation

class CredentialRequestFactory {
    func createCredentialRequest(
        accessToken: String,
        issuer: IssuerMetadata,
        credentialConfigurationId: String,
        proofs: CredentialRequestProofs
    ) throws -> URLRequest {
        guard !proofs.isEmpty else {
            throw InvalidDataProvidedException("Proof collection cannot be empty")
        }

        var request = try constructBaseRequest(
            accessToken: accessToken,
            issuer: issuer
        )
        request.httpBody = try constructRequestBody(
            credentialConfigurationId: credentialConfigurationId,
            proofs: proofs
        )
        return request
    }

    func constructBaseRequest(
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

    func constructRequestBody(
        credentialConfigurationId: String,
        proofs: CredentialRequestProofs
    ) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(
            CredentialRequestBody(
                credential_configuration_id: credentialConfigurationId,
                proofs: proofs
            )
        )
    }
}


private struct CredentialRequestBody: Encodable {
    let credential_configuration_id: String
    let proofs: CredentialRequestProofs
}
