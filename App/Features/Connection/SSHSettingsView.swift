import SwiftUI

/// Saves the SSH config (schema keyed by serverId "kc") to the Keychain as JSON.
/// The tunnel itself is implemented in Phase 2; this only persists config.
struct SSHSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authType = "password"      // "password" | "key"
    @State private var password = ""
    @State private var keyData = ""
    @State private var keyPassphrase = ""
    @State private var localPort = "8003"
    @State private var remoteHost = "127.0.0.1"
    @State private var remotePort = "8003"

    private var isConfigured: Bool {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty,
              !username.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch authType {
        case "password": return !password.isEmpty
        case "key":      return !keyData.isEmpty
        default:         return false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("SSH-Server (kc)") {
                    TextField("Host (z. B. kingscastle.internet-box.ch)", text: $host)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    TextField("Port", text: $port).keyboardType(.numberPad)
                    TextField("Benutzername", text: $username)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    Picker("Auth", selection: $authType) {
                        Text("Passwort").tag("password")
                        Text("Schlüssel").tag("key")
                    }
                }
                if authType == "password" {
                    Section("Passwort") { SecureField("Passwort", text: $password) }
                } else {
                    Section("Schlüssel (PEM)") {
                        TextField("Private Key (PEM)", text: $keyData, axis: .vertical)
                        SecureField("Passphrase (optional)", text: $keyPassphrase)
                    }
                }
                Section("Tunnel") {
                    TextField("Local Port", text: $localPort).keyboardType(.numberPad)
                    TextField("Remote Host", text: $remoteHost)
                    TextField("Remote Port", text: $remotePort).keyboardType(.numberPad)
                }
            }
            .navigationTitle("SSH-Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }.disabled(!isConfigured)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func configDict() -> [String: Any] {
        [
            "serverId": "kc", "host": host, "port": Int(port) ?? 22,
            "username": username, "auth_type": authType, "password": password,
            "key_data": keyData, "key_passphrase": keyPassphrase,
            "local_port": Int(localPort) ?? 8003, "remote_host": remoteHost,
            "remote_port": Int(remotePort) ?? 8003,
        ]
    }

    private func save() {
        if let data = try? JSONSerialization.data(withJSONObject: configDict()),
           let json = String(data: data, encoding: .utf8) {
            Keychain.setSSHConfigJSON(json)
        }
        dismiss()
    }

    private func load() {
        guard let json = Keychain.sshConfigJSON(),
              let data = json.data(using: .utf8),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        host = d["host"] as? String ?? ""
        port = String(d["port"] as? Int ?? 22)
        username = d["username"] as? String ?? ""
        authType = d["auth_type"] as? String ?? "password"
        password = d["password"] as? String ?? ""
        keyData = d["key_data"] as? String ?? ""
        keyPassphrase = d["key_passphrase"] as? String ?? ""
        localPort = String(d["local_port"] as? Int ?? 8003)
        remoteHost = d["remote_host"] as? String ?? "127.0.0.1"
        remotePort = String(d["remote_port"] as? Int ?? 8003)
    }
}
