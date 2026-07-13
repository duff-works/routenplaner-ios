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
    let db: AppDatabase
    let customers: CustomerRepository
    let visits: VisitRepository

    init(store: ConnectionStore = ConnectionStore()) {
        self.store = store
        let api = APIClient(store: store)
        self.api = api
        let database = AppDatabase.shared
        self.db = database
        self.customers = CustomerRepository(api: api, db: database)
        self.visits = VisitRepository(api: api, db: database)
        api.onUnauthorized = { [weak self] in
            Task { @MainActor in self?.handleUnauthorized() }
        }
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

    /// Extern (SSH) connect: bring up the tunnel then advance to login.
    func connectExtern() async throws {
        try await establishTunnel()
        phase = .login
    }

    /// Builds a FRESH tunnel (disconnecting any previous one first) and, only after
    /// it connects, points server_url at the loopback forward. Does not change phase.
    private func establishTunnel() async throws {
        guard let config = SSHTunnelConfig.fromKeychain(), config.isConfigured else {
            throw SSHAuthError.notConfigured
        }
        await tunnel?.disconnect()          // release the previous tunnel + its port (I3)
        let t = SSHTunnel(config: config)
        tunnel = t
        try await t.connect()
        // Bind is on IPv4 127.0.0.1; use it (not "localhost", which also resolves to ::1). (I2)
        store.serverURL = "http://127.0.0.1:\(config.localPort)"
        store.isExtern = true
        store.serverName = "Extern (SSH)"
    }

    /// iOS suspends the app in the background, killing the tunnel with no reliable
    /// death signal — so on return to foreground in extern mode we rebuild a fresh
    /// tunnel rather than trust the old one's (stale) state. (C1)
    func reconnectTunnelIfNeeded() async {
        guard store.isExtern, phase != .connection, tunnel != nil else { return }
        try? await establishTunnel()
    }
}
