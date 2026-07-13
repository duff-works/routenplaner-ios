import XCTest
@testable import RoutenplanerLogic

final class PlaceholderTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(RoutenplanerLogic.version, "0.1.0")
    }
}
