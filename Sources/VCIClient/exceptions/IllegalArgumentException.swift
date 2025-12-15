import Foundation

class IllegalArgumentException: VCIClientException {
    init(_ message: String?) {
        super.init(
            code: "VCI-012",
            message: message ?? "An illegal argument was provided."
        )
    }
}
