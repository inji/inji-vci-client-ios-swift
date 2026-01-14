import XCTest

func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    verify: (Error) -> Void
) async {
    do {
        try await expression()
        XCTFail("Expected error to be thrown")
    } catch {
        verify(error)
    }
}
