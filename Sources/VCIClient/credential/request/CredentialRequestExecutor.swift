import Foundation

class CredentialRequestExecutor {
    private let draft13Factory: CredentialRequestFactoryProtocol
    private let factory: CredentialRequestFactory

    init(
        factory: CredentialRequestFactoryProtocol = CredentialRequestFactoryDraft13(),
        factorySpecVersion1: CredentialRequestFactory = CredentialRequestFactory()
    ) {
        self.draft13Factory = factory
        self.factory = factorySpecVersion1
    }

    func requestCredential(
        issuerMetadata: IssuerMetadata,
        credentialConfigurationId: String,
        proofs: CredentialRequestProofs,
        accessToken: String,
        timeoutInMillis: Int64 = 10000,
        session: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponse? {
        let timeoutSeconds = timeoutInMillis / 1000

        do {
            var request = try factory.createCredentialRequest(
                accessToken: accessToken,
                issuer: issuerMetadata,
                credentialConfigurationId: credentialConfigurationId,
                proofs: proofs
            )

            request.timeoutInterval = TimeInterval(timeoutInMillis) / 1000

            let networkResponse = try await session.sendRequest(request: request)
            let responseBody = networkResponse.body



            if !responseBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                guard var result = try JsonUtils.deserialize(
                    responseBody,
                    as: CredentialResponse.self
                ) else {
                    throw DownloadFailedException(
                        "Failed to parse credential response."
                    )
                }

                result.credentialConfigurationId = credentialConfigurationId
                result.credentialIssuer = issuerMetadata.credentialIssuer

                return result
            }

            Util.logWarning(
                message: "Credential endpoint returned empty body",
                className: String(describing: type(of: self))
            )

            return nil

        } catch let e as NetworkRequestTimeoutException {

            Util.logWarning(
                message: "Credential download timed out after \(timeoutSeconds)s",
                className: String(describing: type(of: self))
            )

            throw DownloadFailedException(
                message: "Credential download timed out after \(timeoutSeconds)s",
                cause: e
            )

        } catch let e as NetworkRequestFailedException {

            Util.logWarning(
                message: "Credential download failed: \(e.message)",
                className: String(describing: type(of: self))
            )

            throw DownloadFailedException(
                message: e.message,
                serverErrorCode: e.serverErrorCode,
                serverErrorDescription: e.serverErrorDescription,
                cause: e
            )

        } catch let e as InvalidPublicKeyException {

            throw DownloadFailedException(
                message: e.message,
                cause: e
            )

        } catch let e as DownloadFailedException {

            throw e

        } catch {

            Util.logWarning(
                message: "Unexpected error during credential download: \(error.localizedDescription)",
                className: String(describing: type(of: self))
            )

            throw DownloadFailedException(
                message: error.localizedDescription,
                cause: error
            )
        }
    }

    func requestCredentialDraft13(
        issuerMetadata: IssuerMetadata,
        credentialConfigurationId: String,
        proof: Proof,
        accessToken: String,
        timeoutInMillis: Int64 = 10000,
        session: NetworkManager = NetworkManager.shared
    ) async throws -> CredentialResponseDraft13? {

        let timeoutSeconds = timeoutInMillis / 1000

        do {
            var request = try draft13Factory.createCredentialRequest(
                credentialFormat: issuerMetadata.credentialFormat,
                accessToken: accessToken,
                issuer: issuerMetadata,
                proofJwt: proof
            )

            request.timeoutInterval = TimeInterval(timeoutInMillis) / 1000

            let networkResponse = try await session.sendRequest(request: request)
            let responseBody = networkResponse.body



            if !responseBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                guard var result = try JsonUtils.deserialize(
                    responseBody,
                    as: CredentialResponseDraft13.self
                ) else {
                    throw DownloadFailedException(
                        "Failed to parse credential response."
                    )
                }

                result.credentialConfigurationId = credentialConfigurationId
                result.credentialIssuer = issuerMetadata.credentialIssuer

                return result
            }

            Util.logWarning(
                message: "Credential endpoint returned empty body",
                className: String(describing: type(of: self))
            )

            return nil

        } catch let e as NetworkRequestTimeoutException {

            Util.logWarning(
                message: "Credential download timed out after \(timeoutSeconds)s",
                className: String(describing: type(of: self))
            )

            throw DownloadFailedException(
                message: "Credential download timed out after \(timeoutSeconds)s",
                cause: e
            )

        } catch let e as NetworkRequestFailedException {

            Util.logWarning(
                message: "Credential download failed: \(e.message)",
                className: String(describing: type(of: self))
            )

            throw DownloadFailedException(
                message: e.message,
                serverErrorCode: e.serverErrorCode,
                serverErrorDescription: e.serverErrorDescription,
                cause: e
            )

        } catch let e as InvalidPublicKeyException {

            throw DownloadFailedException(
                message: e.message,
                cause: e
            )

        } catch let e as DownloadFailedException {

            throw e

        } catch {

            Util.logWarning(
                message: "Unexpected error during credential download: \(error.localizedDescription)",
                className: String(describing: type(of: self))
            )

            throw DownloadFailedException(
                message: error.localizedDescription,
                cause: error
            )
        }
    }

}
