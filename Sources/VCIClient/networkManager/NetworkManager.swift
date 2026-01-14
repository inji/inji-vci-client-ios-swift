import Foundation

struct NetworkResponse {
    let body: String
    let headers: [AnyHashable: Any]?
}

public class NetworkManager {
    public static let shared = NetworkManager()

    init() {}

    func sendRequest(
        url: String,
        method: HttpMethod,
        headers: [String: String]? = nil,
        bodyParams: [String: String]? = nil,
        timeoutMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> NetworkResponse {
        guard let requestURL = URL(string: url) else {
            throw NetworkRequestFailedException("Invalid URL: \(url)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = TimeInterval(timeoutMillis) / 1000

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if method == .post, let params = bodyParams {
            
            
            if((headers?[Header.contentType.rawValue] == ContentTypes.applicationFormUrlEncoded.rawValue)) {
                let bodyString = params
                    .map { "\($0.key.formURLEncoded())=\($0.value.formURLEncoded())" }
                    .joined(separator: "&")
                
                request.httpBody = bodyString.data(using: .utf8)
            } else {
                let jsonData = try JSONEncoder().encode(bodyParams)
                request.httpBody = jsonData
            }
        }

        return try await sendRequest(request: request)
    }
    
    func sendRequestV2(
        url: String,
        method: HttpMethod,
        headers: [String: String]? = nil,
        body: Data? = nil,
        timeoutMillis: Int64 = Constants.defaultNetworkTimeoutInMillis
    ) async throws -> NetworkResponse {
        guard let requestURL = URL(string: url) else {
            throw NetworkRequestFailedException("Invalid URL: \(url)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = TimeInterval(timeoutMillis) / 1000

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if method == .post {
            request.httpBody = body
        }

        return try await sendRequest(request: request)
    }

    func sendRequest(request: URLRequest) async throws -> NetworkResponse {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkRequestFailedException("Invalid response")
            }

            let body = String(data: data, encoding: .utf8) ?? ""
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkRequestFailedException(
                    "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)). Server response: \(body)"
                )
            }

            return NetworkResponse(
                body: body,
                headers: httpResponse.allHeaderFields
            )
        } catch is URLError {
            throw NetworkRequestTimeoutException("Request timed out")
        } catch {
            throw NetworkRequestFailedException(error.localizedDescription)
        }
    }
}
