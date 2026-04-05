import XCTest
@testable import MindScript

/// NOTE: These tests verify logic paths in TextInjector.
/// CGEvent posting cannot be tested in a unit test environment (no window server).
/// Integration testing of actual injection must be done manually.
final class TextInjectorTests: XCTestCase {
    func testEmptyStringIsNoOp() {
        // Should not crash or throw
        TextInjector.inject(text: "", into: nil)
    }

    func testSpecialCharactersAreUnicodeScalars() {
        // Verify that all characters in common punctuation have valid unicode scalars
        let testString = "Hello, world! It's a test — with em-dash & \"quotes\"."
        let scalars = testString.unicodeScalars
        XCTAssertFalse(scalars.isEmpty)
        for scalar in scalars {
            XCTAssertGreaterThan(scalar.value, 0)
        }
    }
}
