import Foundation

/// Shared construction of `.well-known` metadata URLs, kept in one place so the
/// authorization-server discovery and issuer-metadata paths cannot drift apart in this
/// security-sensitive URL handling.
enum WellKnownUrl {

    /// RFC 8414 section 3: insert the well-known `suffix` between the authority and the path of
    /// `baseUrl`. e.g. `https://host/tenant` + `/.well-known/x` -> `https://host/.well-known/x/tenant`.
    /// When `baseUrl` has no path this is equivalent to appending the suffix.
    /// Returns `nil` when `baseUrl` is not a valid absolute URL.
    static func insertSuffix(baseUrl: String, suffix: String) -> String? {
        guard let components = URLComponents(string: baseUrl),
              let scheme = components.scheme,
              let host = components.host else {
            return nil
        }
        let port = components.port.map { ":\($0)" } ?? ""
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        return "\(scheme)://\(host)\(port)\(suffix)\(path)"
    }
}
