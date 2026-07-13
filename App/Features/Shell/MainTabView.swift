import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            NavigationStack { DashboardPlaceholder() }
                .tabItem { Label("Heute", systemImage: "calendar") }
            NavigationStack { PlaceholderScreen(title: "Route") }
                .tabItem { Label("Route", systemImage: "map") }
            NavigationStack { CustomersListView() }
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
    @State private var cacheStatus = ""
    @State private var loading = false

    var body: some View {
        List {
            Section {
                if let name = app.store.serverName {
                    LabeledContent("Server", value: name)
                }
            }
            Section {
                NavigationLink {
                    VisitsListView()
                } label: {
                    Label("Besuche", systemImage: "checklist")
                }
            }
            Section("Daten (Phase 3)") {
                Button {
                    Task { await testCustomerCache() }
                } label: {
                    HStack {
                        Text("Kunden laden + cachen")
                        if loading { Spacer(); ProgressView() }
                    }
                }
                .disabled(loading)
                if !cacheStatus.isEmpty {
                    Text(cacheStatus).font(.footnote).foregroundStyle(.secondary)
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

    private func testCustomerCache() async {
        loading = true
        defer { loading = false }
        let result = await app.customers.list()
        let cached = await app.customers.cachedCount()
        switch result {
        case .success(let list):
            cacheStatus = "\(list.count) Kunden geladen · \(cached) im Cache"
        case .failure(let e):
            cacheStatus = "Fehler: \(e.localizedDescription) · \(cached) im Cache (offline)"
        }
    }
}
