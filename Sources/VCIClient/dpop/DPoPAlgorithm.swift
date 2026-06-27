import Foundation

enum DPoPAlgorithm: String {
    case es256 = "ES256"
    case es384 = "ES384"
    case es512 = "ES512"

    var curveName: String {
        switch self {
        case .es256: return "P-256"
        case .es384: return "P-384"
        case .es512: return "P-521"
        }
    }

    private static let preferenceOrder: [DPoPAlgorithm] = [.es256, .es384, .es512]

    static func select(_ authorizationServerSupported: [String]?) -> DPoPAlgorithm {
        guard let supported = authorizationServerSupported, !supported.isEmpty else {
            return .es256
        }
        return preferenceOrder.first { supported.contains($0.rawValue) } ?? .es256
    }
}
