import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            NavigationStack { DashboardPlaceholder() }
                .tabItem { Label("Heute", systemImage: "calendar") }
            NavigationStack { PlaceholderScreen(title: "Route") }
                .tabItem { Label("Route", systemImage: "map") }
            NavigationStack { PlaceholderScreen(title: "Kunden") }
                .tabItem { Label("Kunden", systemImage: "person.2") }
            NavigationStack { PlaceholderScreen(title: "Punkte") }
                .tabItem { Label("Punkte", systemImage: "star") }
            NavigationStack { MoreScreen() }
                .tabItem { Label("Mehr", systemImage: "ellipsis") }
        }
    }
}

private struct DashboardPlaceholder: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(spacing: 8) {
            Text("Verbunden").font(.title2).bold()
            if let s = app.session {
                Text("\(s.username) · \(s.role)").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Heute")
    }
}

private struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        Text(title).foregroundStyle(.secondary).navigationTitle(title)
    }
}

private struct MoreScreen: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        List {
            Section {
                if let name = app.store.serverName {
                    LabeledContent("Server", value: name)
                }
            }
            Section {
                Button(role: .destructive) {
                    app.logout()
                } label: {
                    Text("Abmelden")
                }
            }
        }
        .navigationTitle("Mehr")
    }
}
