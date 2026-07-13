import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Heute", systemImage: "calendar") }
            NavigationStack { RouteListView() }
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

private struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @State private var pins: [MapPin] = []

    var body: some View {
        VStack(spacing: 0) {
            if let s = app.session {
                VStack(spacing: 2) {
                    Text("Verbunden als \(s.username)").font(.subheadline).bold()
                    Text(s.role).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            GoogleMapView(pins: pins)
                .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("Heute")
        .task { await loadPins() }
    }

    private func loadPins() async {
        if case .success(let customers) = await app.customers.list() {
            pins = customers.compactMap { c in
                guard let lat = c.lat, let lon = c.lon, lat != 0 || lon != 0 else { return nil }
                return MapPin(lat: lat, lon: lon, title: c.displayName, snippet: c.city)
            }
        }
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
