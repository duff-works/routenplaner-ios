import SwiftUI

@main
struct RoutenplanerApp: App {
    @StateObject private var app = AppState()

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
        }
    }
}
