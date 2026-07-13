import SwiftUI

struct CustomersListView: View {
    @EnvironmentObject var app: AppState
    @State private var customers: [Customer] = []
    @State private var search = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            ForEach(customers) { c in
                NavigationLink(value: c.id) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.displayName.isEmpty ? "(ohne Name)" : c.displayName)
                            .font(.headline)
                        let loc = [c.plz, c.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                        if !loc.isEmpty {
                            Text(loc).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Kunden")
        .navigationDestination(for: String.self) { id in
            CustomerDetailView(customerId: id)
        }
        .searchable(text: $search, prompt: "Suchen")
        .task(id: search) {
            // Debounce keystrokes; a new search cancels this task (drops stale results).
            if !search.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            if Task.isCancelled { return }
            await load()
        }
        .refreshable { await load() }
        .overlay {
            if loading && customers.isEmpty { ProgressView() }
            else if !loading && customers.isEmpty && error == nil {
                ContentUnavailableView("Keine Kunden", systemImage: "person.2.slash")
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        switch await app.customers.list(search: search.isEmpty ? nil : search) {
        case .success(let list):
            customers = list
            error = nil
        case .failure(let e):
            error = e.localizedDescription
        }
    }
}
