@testable import VCIClient
import XCTest

final class NetworkManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testSendRequestSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            let data = #"{"status":"ok"}"#.data(using: .utf8)!

            return (response, data)
        }

        let response = try await NetworkManager.shared.sendRequest(
            url: "https://example.com",
            method: .get
        )

        XCTAssertEqual(response.body, #"{"status":"ok"}"#)
    }

    func testSendRequestInvalidURL() async {
        do {
            _ = try await NetworkManager.shared.sendRequest(
                url: "mock",
                method: .get
            )
            XCTFail("Expected invalid URL error")
        } catch {
            XCTAssertTrue(error is NetworkRequestFailedException)
        }
    }

    func testSendRequestHTTPError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!

            let data = "Not Found".data(using: .utf8)!

            return (response, data)
        }

        do {
            _ = try await NetworkManager.shared.sendRequest(
                url: "https://example.com",
                method: .get
            )
            XCTFail("Expected HTTP error")
        } catch {
            XCTAssertTrue(error is NetworkRequestFailedException)
        }
    }

    func testSendRequestTimeout() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await NetworkManager.shared.sendRequest(
                url: "https://example.com",
                method: .get
            )
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertTrue(error is NetworkRequestTimeoutException)
        }
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        MockURLProtocol.lastRequest = request

        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)

        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
