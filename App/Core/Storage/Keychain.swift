import Foundation
import Security

/// Minimal Keychain wrapper (kSecClassGenericPassword, AfterFirstUnlock so
/// background tasks in later phases can read the token while the device is locked).
enum Keychain {
    private static let service = "com.routenplaner.app"

    private static func set(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // Public API
    static func setToken(_ token: String) { set(token, account: "auth_token") }
    static func token() -> String? { get(account: "auth_token") }
    static func deleteToken() { delete(account: "auth_token") }
    static func setSSHConfigJSON(_ json: String) { set(json, account: "ssh_kc") }
    static func sshConfigJSON() -> String? { get(account: "ssh_kc") }
}
