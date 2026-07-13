import XCTest
@testable import RoutenplanerLogic

final class APIErrorTests: XCTestCase {
    func testParseDetail() {
        let d = #"{"detail":"Invalid credentials"}"#.data(using: .utf8)!
        XCTAssertEqual(parseErrorDetail(d), "Invalid credentials")
    }
    func testParseDetailMissing() {
        XCTAssertNil(parseErrorDetail(#"{"other":1}"#.data(using: .utf8)!))
    }
    func testMap200IsNil() {
        XCTAssertNil(mapHTTPStatus(200, body: Data()))
    }
    func testMap401IsUnauthorized() {
        XCTAssertEqual(mapHTTPStatus(401, body: Data()), .unauthorized)
    }
    func testMap500CarriesDetail() {
        let d = #"{"detail":"boom"}"#.data(using: .utf8)!
        XCTAssertEqual(mapHTTPStatus(500, body: d), .http(status: 500, detail: "boom"))
    }
}
