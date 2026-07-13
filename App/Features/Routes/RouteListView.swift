import SwiftUI

struct RouteListView: View {
    @EnvironmentObject var app: AppState
    @State private var routes: [Route] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            ForEach(routes) { r in
                NavigationLink(value: r.id) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name ?? "Route").font(.headline)
                        HStack {
                            Text(r.date ?? "").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(statusLabel(r.status)).font(.caption).foregroundStyle(statusColor(r.status))
                        }
                    }
                }
            }
        }
        .navigationTitle("Routen")
        .navigationDestination(for: String.self) { id in
            RouteDetailView(routeId: id)
        }
        .task { if routes.isEmpty { await load() } }
        .refreshable { await load() }
        .overlay {
            if loading && routes.isEmpty { ProgressView() }
            else if !loading && routes.isEmpty && error == nil {
                ContentUnavailableView("Keine Routen", systemImage: "map")
            }
        }
    }

    private func statusLabel(_ s: String?) -> String {
        switch s {
        case "completed": return "Fertig"
        case "in_progress": return "Aktiv"
        default: return "Geplant"
        }
    }

    private func statusColor(_ s: String?) -> Color {
        switch s {
        case "completed": return .green
        case "in_progress": return .blue
        default: return .secondary
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            routes = try await app.api.getRoutes()
            error = nil
        } catch {
            self.error = "Routen konnten nicht geladen werden."
        }
    }
}
