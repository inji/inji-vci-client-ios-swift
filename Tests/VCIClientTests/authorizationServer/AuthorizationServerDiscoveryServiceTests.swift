@testable import VCIClient
import XCTest

final class AuthorizationServerDiscoveryServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testDiscover_returnsOAuthMetadataWhenOAuthEndpointSucceeds() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            let data = """
            {
                "issuer": "https://issuer.example.com",
                "token_endpoint": "https://issuer.example.com/token",
                "authorization_endpoint": "https://issuer.example.com/auth"
            }
            """.data(using: .utf8)!

            return (response, data)
        }

        let metadata = try await AuthorizationServerDiscoveryService().discover(
            baseUrl: "https://issuer.example.com"
        )

        XCTAssertEqual(metadata.issuer, "https://issuer.example.com")
        XCTAssertEqual(metadata.tokenEndpoint, "https://issuer.example.com/token")
    }

    func testDiscover_fallsBackToOpenIdWhenOAuthResponseIsBlank() async throws {
        var requestedUrls: [String] = []

        MockURLProtocol.requestHandler = { request in
            requestedUrls.append(request.url!.absoluteString)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            if request.url!.absoluteString.contains("oauth-authorization-server") {
                return (response, Data())
            }

            let data = """
            {
                "issuer": "https://issuer.example.com",
                "token_endpoint": "https://issuer.example.com/token",
                "authorization_endpoint": "https://issuer.example.com/auth"
            }
            """.data(using: .utf8)!

            return (response, data)
        }

        let metadata = try await AuthorizationServerDiscoveryService().discover(
            baseUrl: "https://issuer.example.com"
        )

        XCTAssertEqual(requestedUrls.count, 2)
        XCTAssertTrue(requestedUrls[0].contains(".well-known/oauth-authorization-server"))
        XCTAssertTrue(requestedUrls[1].contains(".well-known/openid-configuration"))
        XCTAssertEqual(metadata.authorizationEndpoint, "https://issuer.example.com/auth")
    }

    func testDiscover_fallsBackToOpenIdWhenOAuthRequestFails() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.url!.absoluteString.contains("oauth-authorization-server") {
                throw URLError(.cannotFindHost)
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
                "issuer": "https://issuer.example.com",
                "token_endpoint": "https://issuer.example.com/token"
            }
            """.data(using: .utf8)!

            return (response, data)
        }

        let metadata = try await AuthorizationServerDiscoveryService().discover(
            baseUrl: "https://issuer.example.com"
        )

        XCTAssertEqual(metadata.tokenEndpoint, "https://issuer.example.com/token")
    }

    func testDiscover_throwsWhenBothDiscoveryEndpointsFail() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.cannotFindHost)
        }

        do {
            _ = try await AuthorizationServerDiscoveryService().discover(
                baseUrl: "https://issuer.example.com"
            )
            XCTFail("Expected discovery failure")
        } catch let error as AuthorizationServerDiscoveryException {
            XCTAssertTrue(error.message.contains("Failed to discover authorization server metadata"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDiscover_throwsWhenBothResponsesAreInvalid() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            if request.url!.absoluteString.contains("oauth-authorization-server") {
                return (response, "not-json".data(using: .utf8)!)
            }

            return (response, Data("   ".utf8))
        }

        do {
            _ = try await AuthorizationServerDiscoveryService().discover(
                baseUrl: "https://issuer.example.com"
            )
            XCTFail("Expected discovery failure")
        } catch let error as AuthorizationServerDiscoveryException {
            XCTAssertTrue(error.message.contains("Failed to discover authorization server metadata"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
