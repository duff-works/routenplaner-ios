import SwiftUI
import GoogleMaps

@main
struct RoutenplanerApp: App {
    @StateObject private var app = AppState()

    init() {
        if let key = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String,
           !key.isEmpty, key != "placeholder" {
            GMSServices.provideAPIKey(key)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch app.phase {
                case .connection: ConnectionView()
                case .login:      LoginView()
                case .main:       MainTabView()
                }
            }
            .environmentObject(app)
            .tint(.kcGold)
        }
    }
}
