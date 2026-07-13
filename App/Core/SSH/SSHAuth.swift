import Foundation
import Citadel
import Crypto

/// Mirrors the Android SshTunnelConfig schema (serverId "kc"), loaded from the
/// Keychain JSON that SSHSettingsView writes.
struct SSHTunnelConfig {
    var host = ""
    var port = 22
    var username = ""
    var authType = "password"   // "password" | "key"
    var password = ""
    var keyData = ""            // OpenSSH-format private key (PEM)
    var keyPassphrase = ""
    var localPort = 8003
    var remoteHost = "127.0.0.1"
    var remotePort = 8003

    var isConfigured: Bool {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty,
              !username.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch authType {
        case "password": return !password.isEmpty
        case "key":      return !keyData.isEmpty
        default:         return false
        }
    }

    static func fromKeychain() -> SSHTunnelConfig? {
        guard let json = Keychain.sshConfigJSON(),
              let data = json.data(using: .utf8),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var c = SSHTunnelConfig()
        c.host = d["host"] as? String ?? ""
        c.port = d["port"] as? Int ?? 22
        c.username = d["username"] as? String ?? ""
        c.authType = d["auth_type"] as? String ?? "password"
        c.password = d["password"] as? String ?? ""
        c.keyData = d["key_data"] as? String ?? ""
        c.keyPassphrase = d["key_passphrase"] as? String ?? ""
        c.localPort = d["local_port"] as? Int ?? 8003
        c.remoteHost = d["remote_host"] as? String ?? "127.0.0.1"
        c.remotePort = d["remote_port"] as? Int ?? 8003
        return c
    }
}

enum SSHAuthError: Error { case notConfigured, invalidKey }

/// Builds a Citadel authentication method. Prefers ed25519; falls back to RSA
/// (ssh-rsa/SHA-1 — needs `algorithms: .all` and a server that still allows it).
/// Only OpenSSH-container private keys parse; classic PKCS#1/PKCS#8 PEMs throw.
func makeSSHAuthMethod(_ c: SSHTunnelConfig) throws -> SSHAuthenticationMethod {
    switch c.authType {
    case "key":
        let passphrase = c.keyPassphrase.isEmpty ? nil : c.keyPassphrase.data(using: .utf8)
        if let ed = try? Curve25519.Signing.PrivateKey(sshEd25519: c.keyData, decryptionKey: passphrase) {
            return .ed25519(username: c.username, privateKey: ed)
        }
        if let rsa = try? Insecure.RSA.PrivateKey(sshRsa: c.keyData, decryptionKey: passphrase) {
            return .rsa(username: c.username, privateKey: rsa)
        }
        throw SSHAuthError.invalidKey
    default:
        return .passwordBased(username: c.username, password: c.password)
    }
}
