import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var vm = LoginViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Benutzername", text: $vm.username)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    SecureField("Passwort", text: $vm.password)
                }
                if let msg = vm.errorMessage {
                    Text(msg).foregroundStyle(.red)
                }
                Section {
                    Button {
                        Task { await vm.login(app: app) }
                    } label: {
                        if vm.isLoading { ProgressView() } else { Text("Anmelden") }
                    }
                    .disabled(vm.isLoading)
                }
            }
            .navigationTitle("Anmelden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Server wechseln") { app.backToConnection() }
                }
            }
        }
    }
}
