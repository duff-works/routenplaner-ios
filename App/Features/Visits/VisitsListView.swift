import SwiftUI

struct VisitsListView: View {
    @EnvironmentObject var app: AppState
    @State private var visits: [Visit] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            ForEach(visits) { v in
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.customerName ?? v.customerCompany ?? v.customerId ?? "Besuch")
                        .font(.headline)
                    HStack {
                        Text(v.date ?? "").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(statusLabel(v.status)).font(.caption).foregroundStyle(statusColor(v.status))
                    }
                }
            }
        }
        .navigationTitle("Besuche")
        .task { if visits.isEmpty { await load() } }
        .refreshable { await load() }
        .overlay {
            if loading && visits.isEmpty { ProgressView() }
            else if !loading && visits.isEmpty && error == nil {
                ContentUnavailableView("Keine Besuche", systemImage: "calendar.badge.exclamationmark")
            }
        }
    }

    private func statusLabel(_ s: String?) -> String {
        switch s {
        case "completed": return "Erledigt"
        case "in_progress": return "Aktiv"
        case "abgesagt": return "Abgesagt"
        default: return "Geplant"
        }
    }

    private func statusColor(_ s: String?) -> Color {
        switch s {
        case "completed": return .green
        case "in_progress": return .blue
        case "abgesagt": return .red
        default: return .secondary
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        switch await app.visits.list() {
        case .success(let list):
            visits = list
            error = nil
        case .failure(let e):
            error = e.localizedDescription
        }
    }
}
