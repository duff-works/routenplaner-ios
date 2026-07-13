import Foundation
import UIKit

enum AppPhase { case connection, login, main }

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .connection   // always start at connection (mirrors Android)
    @Published var session: UserSession?
    @Published var tunnel: SSHTunnel?

    let store: ConnectionStore
    let api: APIClient

    init(store: ConnectionStore = ConnectionStore()) {
        self.store = store
        self.api = APIClient(store: store)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reconnectTunnelIfNeeded() }
        }
    }

    func completeLogin(_ session: UserSession) {
        Keychain.setToken(session.token)
        self.session = session
        phase = .main
    }

    /// Optimistic local logout: clear the session immediately (don't block the UI
    /// on the network), then fire a best-effort server logout in the background.
    func logout() {
        let token = Keychain.token()
        Keychain.deleteToken()
        session = nil
        phase = .login
        if let token {
            Task { await api.logout(token: token) }
        }
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

    /// Extern (SSH) connect: load the Keychain config, bring up the tunnel, and
    /// only after it reports connected point server_url at the loopback forward.
    func connectExtern() async throws {
        guard let config = SSHTunnelConfig.fromKeychain(), config.isConfigured else {
            throw SSHAuthError.notConfigured
        }
        let t = SSHTunnel(config: config)
        tunnel = t
        try await t.connect()
        store.serverURL = "http://localhost:\(config.localPort)"
        store.isExtern = true
        store.serverName = "Extern (SSH)"
        phase = .login
    }

    /// iOS suspends the app in the background, killing the tunnel; rebuild it on
    /// return to foreground when the extern path is active.
    func reconnectTunnelIfNeeded() async {
        guard store.isExtern, let t = tunnel, !t.isConnected else { return }
        try? await t.connect()
    }
}
