import Foundation

public func makeAPIJSONDecoder() -> JSONDecoder {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}

public struct LoginRequest: Encodable {
    public let username: String
    public let password: String
    public init(username: String, password: String) {
        self.username = username; self.password = password
    }
}

public struct UserAddress: Codable, Equatable {
    public let street: String
    public let plz: String
    public let city: String
    public let country: String
}

public struct LoginResponse: Decodable {
    public let token: String
    public let username: String
    public let role: String
    public let permissions: [String]
    public let sidebarAccess: [String]
    public let allowedThemes: [String]
    public let language: String?
    public let address: UserAddress?
}

public struct VerifyRequest: Encodable {
    public let token: String
    public init(token: String) { self.token = token }
}

public struct LogoutRequest: Encodable {
    public let token: String
    public init(token: String) { self.token = token }
}

public struct VerifyResponse: Decodable {
    public let valid: Bool
    public let username: String?
    public let role: String?
    public let permissions: [String]?
    public let sidebarAccess: [String]?
}

public struct SuccessResponse: Decodable {
    public let success: Bool
}

public struct UserSession: Equatable {
    public let token: String
    public let username: String
    public let role: String
    public let permissions: [String]
    public let sidebarAccess: [String]
    public let address: UserAddress?
    public init(token: String, username: String, role: String,
                permissions: [String], sidebarAccess: [String], address: UserAddress?) {
        self.token = token; self.username = username; self.role = role
        self.permissions = permissions; self.sidebarAccess = sidebarAccess; self.address = address
    }
    public var isSuperadmin: Bool { permissions.contains("all") }
}

public extension UserSession {
    /// Build a session from a successful login response.
    init(login r: LoginResponse) {
        self.init(token: r.token, username: r.username, role: r.role,
                  permissions: r.permissions, sidebarAccess: r.sidebarAccess, address: r.address)
    }
}
