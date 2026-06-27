@testable import VCIClient
import XCTest

final class DPoPCredentialRequestSenderTests: XCTestCase {

    private let credentialEndpoint = "https://issuer.example.com/credential"
    private let accessToken = "access-token"

    private final class Recorder {
        var sent: [URLRequest] = []
        private var outcomes: [() throws -> NetworkResponse]
        private var index = 0

        init(_ outcomes: [() throws -> NetworkResponse]) {
            self.outcomes = outcomes
        }

        func send(_ request: URLRequest) async throws -> NetworkResponse {
            sent.append(request)
            defer { index += 1 }
            return try outcomes[index]()
        }
    }

    private func baseRequest() -> URLRequest {
        var request = URLRequest(url: URL(string: credentialEndpoint)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func dpopManager() -> DPoPManager {
        let manager = DPoPManager()
        manager.initialize(tokenEndpoint: "https://as.example.com/token", authorizationServerSupportedAlgorithms: ["ES256"])
        return manager
    }

    private func ok() -> NetworkResponse {
        NetworkResponse(body: #"{"credential":"vc"}"#, headers: nil)
    }

    private func unauthorized(_ headers: [AnyHashable: Any]) -> NetworkRequestFailedException {
        NetworkRequestFailedException(message: "HTTP 401", httpStatusCode: 401, headers: headers)
    }

    func test_bearerTokenTypeSentUnchanged() async throws {
        let recorder = Recorder([{ self.ok() }])
        let sender = DPoPCredentialRequestSender(sendRequest: recorder.send)

        _ = try await sender.send(
            baseRequest: baseRequest(),
            accessToken: accessToken,
            credentialEndpoint: credentialEndpoint,
            tokenType: "Bearer",
            dpopManager: dpopManager()
        )

        XCTAssertEqual(recorder.sent.count, 1)
        XCTAssertEqual(recorder.sent[0].value(forHTTPHeaderField: "Authorization"), "Bearer \(accessToken)")
        XCTAssertNil(recorder.sent[0].value(forHTTPHeaderField: "DPoP"))
    }

    func test_dpopTokenTypeSendsDpopAuthorizationAndProof() async throws {
        let recorder = Recorder([{ self.ok() }])
        let sender = DPoPCredentialRequestSender(sendRequest: recorder.send)

        _ = try await sender.send(
            baseRequest: baseRequest(),
            accessToken: accessToken,
            credentialEndpoint: credentialEndpoint,
            tokenType: "DPoP",
            dpopManager: dpopManager()
        )

        let request = try XCTUnwrap(recorder.sent.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "DPoP \(accessToken)")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "DPoP"))
    }

    func test_useDpopNonceChallengeIsRetriedWithNonce() async throws {
        let recorder = Recorder([
            { throw self.unauthorized([
                "WWW-Authenticate": #"DPoP error="use_dpop_nonce""#,
                "DPoP-Nonce": "server-nonce",
            ]) },
            { self.ok() },
        ])
        let sender = DPoPCredentialRequestSender(sendRequest: recorder.send)

        _ = try await sender.send(
            baseRequest: baseRequest(),
            accessToken: accessToken,
            credentialEndpoint: credentialEndpoint,
            tokenType: "DPoP",
            dpopManager: dpopManager()
        )

        XCTAssertEqual(recorder.sent.count, 2)
        let retryProof = try XCTUnwrap(recorder.sent[1].value(forHTTPHeaderField: "DPoP"))
        let claimsData = try XCTUnwrap(try Data(base64URLEncodedString: retryProof.components(separatedBy: ".")[1]))
        let claims = try XCTUnwrap(try JSONSerialization.jsonObject(with: claimsData) as? [String: Any])
        XCTAssertEqual(claims["nonce"] as? String, "server-nonce")
    }

    func test_bearerOnlyChallengeTriggersBearerRetry() async throws {
        let recorder = Recorder([
            { throw self.unauthorized(["WWW-Authenticate": #"Bearer error="invalid_token""#]) },
            { self.ok() },
        ])
        let sender = DPoPCredentialRequestSender(sendRequest: recorder.send)

        _ = try await sender.send(
            baseRequest: baseRequest(),
            accessToken: accessToken,
            credentialEndpoint: credentialEndpoint,
            tokenType: "DPoP",
            dpopManager: dpopManager()
        )

        XCTAssertEqual(recorder.sent.count, 2)
        XCTAssertEqual(recorder.sent[1].value(forHTTPHeaderField: "Authorization"), "Bearer \(accessToken)")
        XCTAssertNil(recorder.sent[1].value(forHTTPHeaderField: "DPoP"))
    }

    func test_dpopChallengeWithoutNonceIsNotDowngraded() async throws {
        let recorder = Recorder([
            { throw self.unauthorized(["WWW-Authenticate": #"DPoP error="invalid_dpop_proof""#]) },
        ])
        let sender = DPoPCredentialRequestSender(sendRequest: recorder.send)

        do {
            _ = try await sender.send(
                baseRequest: baseRequest(),
                accessToken: accessToken,
                credentialEndpoint: credentialEndpoint,
                tokenType: "DPoP",
                dpopManager: dpopManager()
            )
            XCTFail("Expected failure")
        } catch is NetworkRequestFailedException {
            XCTAssertEqual(recorder.sent.count, 1)
        }
    }

    func test_non401FailuresArePropagated() async throws {
        let recorder = Recorder([
            { throw NetworkRequestFailedException(message: "HTTP 500", httpStatusCode: 500, headers: nil) },
        ])
        let sender = DPoPCredentialRequestSender(sendRequest: recorder.send)

        do {
            _ = try await sender.send(
                baseRequest: baseRequest(),
                accessToken: accessToken,
                credentialEndpoint: credentialEndpoint,
                tokenType: "DPoP",
                dpopManager: dpopManager()
            )
            XCTFail("Expected failure")
        } catch is NetworkRequestFailedException {
            XCTAssertEqual(recorder.sent.count, 1)
        }
    }
}
