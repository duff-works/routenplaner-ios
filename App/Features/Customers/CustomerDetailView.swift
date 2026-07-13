import SwiftUI

struct CustomerDetailView: View {
    let customerId: String
    @EnvironmentObject var app: AppState
    @State private var customer: Customer?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Form {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let c = customer {
                stammdaten(c)
                if let contacts = c.contacts, !contacts.isEmpty {
                    Section("Kontakte") {
                        ForEach(contacts) { ContactRow(contact: $0) }
                    }
                }
                ladenprofil(c)
                sortiment(c)
                kategorien(c)
            } else if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle(customer?.displayName ?? "Kunde")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder private func stammdaten(_ c: Customer) -> some View {
        Section("Stammdaten") {
            let street = c.street ?? ""
            let loc = [c.plz, c.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let addr = [street, loc].filter { !$0.isEmpty }.joined(separator: ", ")
            if !addr.isEmpty { LabeledContent("Adresse", value: addr) }
            if let p = c.phone, !p.isEmpty { LabeledContent("Telefon", value: p) }
            if let e = c.email, !e.isEmpty { LabeledContent("E-Mail", value: e) }
            if let n = c.notes, !n.isEmpty { LabeledContent("Notizen", value: n) }
            if let vpy = c.visitsPerYear, vpy > 0 { LabeledContent("Besuche/Jahr", value: "\(vpy)") }
        }
    }

    @ViewBuilder private func ladenprofil(_ c: Customer) -> some View {
        let hasSuppliers = !(c.suppliers ?? []).isEmpty
        if !(c.storeType ?? "").isEmpty || !(c.assortmentPotential ?? "").isEmpty || hasSuppliers {
            Section("Ladenprofil") {
                if let st = c.storeType, !st.isEmpty { LabeledContent("Ladentyp", value: st) }
                if let ap = c.assortmentPotential, !ap.isEmpty { LabeledContent("Sortimentspotenzial", value: ap) }
                ForEach(Array((c.suppliers ?? []).enumerated()), id: \.offset) { _, s in
                    LabeledContent(s.name ?? "Lieferant", value: s.satisfaction.map { "\($0)/5" } ?? "–")
                }
            }
        }
    }

    @ViewBuilder private func sortiment(_ c: Customer) -> some View {
        if let items = c.sortiment, !items.isEmpty {
            Section("Sortiment") {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    LabeledContent(item.name ?? item.artNr ?? "–", value: "\(item.qty ?? 0)")
                }
            }
        }
    }

    @ViewBuilder private func kategorien(_ c: Customer) -> some View {
        let active = (c.sortimentCategories ?? [:]).filter { $0.value }.keys.sorted()
        if !active.isEmpty {
            Section("Sortiment-Kategorien") {
                ForEach(active, id: \.self) { Text($0) }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            customer = try await app.api.getCustomer(id: customerId)
            error = nil
        } catch {
            self.error = "Kunde konnte nicht geladen werden."
        }
    }
}

private struct ContactRow: View {
    let contact: Contact
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(contact.name ?? "(ohne Name)").font(.headline)
                Spacer()
                StarRating(rating: contact.rating ?? 0)
            }
            if let role = contact.role, !role.isEmpty {
                Text(role).font(.caption).foregroundStyle(.secondary)
            }
            if let phone = contact.phone, !phone.isEmpty {
                Text(phone).font(.caption)
            }
        }
    }
}

private struct StarRating: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(i <= rating ? .yellow : .secondary)
            }
        }
    }
}
