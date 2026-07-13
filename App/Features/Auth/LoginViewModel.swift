import Foundation
import RoutenplanerLogic

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(app: AppState) async {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            errorMessage = "Benutzername und Passwort erforderlich."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await app.api.login(username: username, password: password)
            app.completeLogin(UserSession(login: resp))
        } catch APIError.unauthorized {
            errorMessage = "Ungültige Zugangsdaten."
        } catch APIError.http(_, let detail) {
            errorMessage = detail ?? "Serverfehler."
        } catch APIError.timeout {
            errorMessage = "Zeitüberschreitung. Server erreichbar?"
        } catch {
            errorMessage = "Verbindung fehlgeschlagen."
        }
    }
}
