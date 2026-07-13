import SwiftUI
import RoutenplanerLogic

struct ConnectionView: View {
    @EnvironmentObject var app: AppState
    @State private var localInput: String = ""
    @State private var showSSH = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lokal (WLAN)") {
                    TextField("z. B. 192.168.1.156:8003", text: $localInput)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Verbinden (Lokal)") { connectLocal() }
                }
                Section("Extern (SSH)") {
                    Button("SSH-Einstellungen") { showSSH = true }
                    Text("Der SSH-Tunnel wird in Phase 2 aktiviert.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("Verbindung")
            .sheet(isPresented: $showSSH) { SSHSettingsView() }
            .onAppear { localInput = app.store.lastLocalIP ?? "192.168.1.156:8003" }
        }
    }

    private func connectLocal() {
        guard let origin = normalizeServerInput(localInput) else {
            error = "Ungültige Adresse."
            return
        }
        app.store.serverURL = origin
        app.store.isExtern = false
        app.store.lastLocalIP = localInput
        app.store.serverName = "Lokal (\(localInput))"
        error = nil
        app.phase = .login
    }
}
