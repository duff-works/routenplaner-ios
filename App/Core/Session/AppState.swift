import Foundation
import RoutenplanerLogic

enum AppPhase { case connection, login, main }

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .connection   // always start at connection (mirrors Android)
    @Published var session: UserSession?

    let store: ConnectionStore
    let api: APIClient

    init(store: ConnectionStore = ConnectionStore()) {
        self.store = store
        self.api = APIClient(store: store)
    }

    func completeLogin(_ session: UserSession) {
        Keychain.setToken(session.token)
        self.session = session
        phase = .main
    }

    func logout() async {
        await api.logout()
        Keychain.deleteToken()
        session = nil
        phase = .login
    }

    /// Called when any authenticated request returns 401 mid-session.
    func handleUnauthorized() {
        Keychain.deleteToken()
        session = nil
        phase = .login
    }

    func backToConnection() {
        phase = .connection
    }
}
