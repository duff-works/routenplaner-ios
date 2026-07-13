import Foundation

/// Persists the connection origin + mode. Mirrors Android's server_url / is_extern
/// prefs. The APIClient reads `serverURL` fresh on every request.
final class ConnectionStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private enum Key {
        static let serverURL = "server_url"
        static let isExtern = "is_extern"
        static let serverName = "server_name"
        static let lastLocalIP = "last_local_ip"
    }

    var serverURL: String? {
        get { defaults.string(forKey: Key.serverURL) }
        set { defaults.set(newValue, forKey: Key.serverURL) }
    }
    var isExtern: Bool {
        get { defaults.bool(forKey: Key.isExtern) }
        set { defaults.set(newValue, forKey: Key.isExtern) }
    }
    var serverName: String? {
        get { defaults.string(forKey: Key.serverName) }
        set { defaults.set(newValue, forKey: Key.serverName) }
    }
    var lastLocalIP: String? {
        get { defaults.string(forKey: Key.lastLocalIP) }
        set { defaults.set(newValue, forKey: Key.lastLocalIP) }
    }
}
