import XCTest
@testable import SwiftMessages

final class SwiftMessagesTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SwiftMessages().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
