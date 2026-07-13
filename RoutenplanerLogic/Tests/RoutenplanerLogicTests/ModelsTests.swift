import XCTest
@testable import RoutenplanerLogic

final class ModelsTests: XCTestCase {
    func testLoginResponseDecodesSnakeCase() throws {
        let json = """
        {"token":"abc123","username":"shane","role":"user",
         "permissions":["view"],"sidebar_access":["dashboard","kunden"],
         "allowed_themes":["kc"],"language":"de",
         "address":{"street":"Weg 1","plz":"3000","city":"Bern","country":"CH"}}
        """.data(using: .utf8)!
        let r = try makeAPIJSONDecoder().decode(LoginResponse.self, from: json)
        XCTAssertEqual(r.token, "abc123")
        XCTAssertEqual(r.sidebarAccess, ["dashboard", "kunden"])
        XCTAssertEqual(r.address?.city, "Bern")
    }
    func testLoginRequestEncodes() throws {
        let data = try JSONEncoder().encode(LoginRequest(username: "u", password: "p"))
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: String]
        XCTAssertEqual(obj["username"], "u")
        XCTAssertEqual(obj["password"], "p")
    }
    func testSuperadminWildcard() {
        let s = UserSession(token: "t", username: "u", role: "superadmin",
                            permissions: ["all"], sidebarAccess: [], address: nil)
        XCTAssertTrue(s.isSuperadmin)
    }
    func testVerifyResponseInvalid() throws {
        let json = #"{"valid":false}"#.data(using: .utf8)!
        let r = try makeAPIJSONDecoder().decode(VerifyResponse.self, from: json)
        XCTAssertFalse(r.valid)
        XCTAssertNil(r.username)
    }
}
