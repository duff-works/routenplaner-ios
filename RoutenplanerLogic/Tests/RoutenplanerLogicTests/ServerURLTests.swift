import XCTest
@testable import RoutenplanerLogic

final class ServerURLTests: XCTestCase {
    func testNormalizeBareIPAddsSchemeAndDefaultPort() {
        XCTAssertEqual(normalizeServerInput("192.168.1.156"), "http://192.168.1.156:8003")
    }
    func testNormalizeHostWithPortKeepsPort() {
        XCTAssertEqual(normalizeServerInput("192.168.1.156:9000"), "http://192.168.1.156:9000")
    }
    func testNormalizeStripsTrailingSlashAndWhitespace() {
        XCTAssertEqual(normalizeServerInput("  192.168.1.156:8003/  "), "http://192.168.1.156:8003")
    }
    func testNormalizeKeepsExplicitScheme() {
        XCTAssertEqual(normalizeServerInput("http://localhost:8003"), "http://localhost:8003")
    }
    func testNormalizeRejectsEmpty() {
        XCTAssertNil(normalizeServerInput("   "))
    }
    func testComposeOverlaysOriginOntoPath() {
        let url = composeURL(origin: "http://192.168.1.156:8003", path: "/auth/verify")
        XCTAssertEqual(url?.absoluteString, "http://192.168.1.156:8003/auth/verify")
    }
    func testComposeAppendsQueryItems() {
        let url = composeURL(origin: "http://h:8003", path: "/kunden",
                             queryItems: [URLQueryItem(name: "token", value: "abc")])
        XCTAssertEqual(url?.absoluteString, "http://h:8003/kunden?token=abc")
    }
    func testComposeNormalizesLeadingSlashOnPath() {
        let a = composeURL(origin: "http://h:8003", path: "auth/login")?.absoluteString
        let b = composeURL(origin: "http://h:8003", path: "/auth/login")?.absoluteString
        XCTAssertEqual(a, "http://h:8003/auth/login")
        XCTAssertEqual(a, b)
    }
}
