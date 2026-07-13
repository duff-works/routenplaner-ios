import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var app: AppState
    @State private var localInput: String = ""
    @State private var showSSH = false
    @State private var error: String?

    @State private var externConnecting = false
    @State private var sshConfigured = false
    @State private var sshError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lokal (WLAN)") {
                    TextField("z. B. 192.168.1.156:8003", text: $localInput)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Verbinden (Lokal)") { connectLocal() }
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
                Section("Extern (SSH)") {
                    Button("SSH-Einstellungen") { showSSH = true }
                    Button {
                        connectExtern()
                    } label: {
                        HStack {
                            Text("Verbinden (Extern)")
                            if externConnecting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(externConnecting || !sshConfigured)
                    if !sshConfigured {
                        Text("SSH-Einstellungen zuerst ausfüllen.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let sshError {
                        Text(sshError).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Verbindung")
            .sheet(isPresented: $showSSH, onDismiss: refreshSSHConfigured) {
                SSHSettingsView()
            }
            .onAppear {
                localInput = app.store.lastLocalIP ?? "192.168.1.156:8003"
                refreshSSHConfigured()
            }
        }
    }

    private func refreshSSHConfigured() {
        sshConfigured = SSHTunnelConfig.fromKeychain()?.isConfigured ?? false
    }

    private func connectLocal() {
        guard let origin = normalizeServerInput(localInput) else {
            error = "Ungültige Adresse."
            return
        }
        let cleaned = localInput.trimmingCharacters(in: .whitespacesAndNewlines)
        app.store.serverURL = origin
        app.store.isExtern = false
        app.store.lastLocalIP = cleaned
        app.store.serverName = "Lokal (\(cleaned))"
        error = nil
        app.phase = .login
    }

    private func connectExtern() {
        externConnecting = true
        sshError = nil
        Task {
            do {
                try await app.connectExtern()
                // On success the AppState gate advances to .login (root switches away).
            } catch {
                if case .failed(let msg)? = app.tunnel?.state {
                    sshError = msg
                } else if error is SSHAuthError {
                    sshError = "SSH-Einstellungen unvollständig."
                } else {
                    sshError = "SSH-Verbindung fehlgeschlagen."
                }
            }
            externConnecting = false
        }
    }
}
