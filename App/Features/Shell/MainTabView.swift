import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            NavigationStack { DashboardView(api: app.api) }
                .tabItem { Label("Heute", systemImage: "calendar") }
            NavigationStack { RouteListView() }
                .tabItem { Label("Route", systemImage: "map") }
            NavigationStack { CustomersListView() }
                .tabItem { Label("Kunden", systemImage: "person.2") }
            NavigationStack { PunkteView() }
                .tabItem { Label("Punkte", systemImage: "star") }
            NavigationStack { MoreScreen() }
                .tabItem { Label("Mehr", systemImage: "ellipsis") }
        }
    }
}

private struct MoreScreen: View {
    @EnvironmentObject var app: AppState

    private var isAdmin: Bool {
        guard let s = app.session else { return false }
        return s.role == "admin" || s.role == "superadmin" || s.permissions.contains("all")
    }

    var body: some View {
        List {
            Section {
                if let name = app.store.serverName {
                    LabeledContent("Server", value: name)
                }
            }
            Section {
                NavigationLink { VisitsListView() } label: { Label("Besuche", systemImage: "checklist") }
                NavigationLink { RegionsView() } label: { Label("Regionen", systemImage: "map") }
                NavigationLink { AktionenView() } label: { Label("Aktionen", systemImage: "megaphone") }
                if isAdmin {
                    NavigationLink { AnfragenView() } label: { Label("Anfragen", systemImage: "tray") }
                    NavigationLink { UsersView() } label: { Label("Benutzer", systemImage: "person.3") }
                }
            }
            Section {
                NavigationLink { SettingsView() } label: { Label("Einstellungen", systemImage: "gearshape") }
                NavigationLink { UpdateView() } label: { Label("Update", systemImage: "arrow.down.circle") }
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
