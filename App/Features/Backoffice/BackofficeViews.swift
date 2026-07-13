import SwiftUI

// MARK: - Regionen

struct RegionsView: View {
    @EnvironmentObject var app: AppState
    @State private var regions: [Region] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            ForEach(regions) { r in
                HStack {
                    Circle().fill(Color(hex: r.color) ?? .gray).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.name ?? "Region").font(.subheadline)
                        if let g = r.group, !g.isEmpty {
                            Text(g).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(r.customerCount ?? 0)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Regionen")
        .task { if regions.isEmpty { await load() } }
        .refreshable { await load() }
        .overlay { if loading && regions.isEmpty { ProgressView() } }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do { regions = try await app.api.getRegions(); error = nil }
        catch { self.error = "Regionen konnten nicht geladen werden." }
    }
}

// MARK: - Aktionen

struct AktionenView: View {
    @EnvironmentObject var app: AppState
    @State private var aktionen: [Aktion] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            ForEach(aktionen) { a in
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.title ?? "Aktion").font(.subheadline).bold()
                    if let d = a.description, !d.isEmpty {
                        Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack {
                        Text([a.startDate, a.endDate].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " – "))
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(a.status ?? "").font(.caption2)
                    }
                }
            }
        }
        .navigationTitle("Aktionen")
        .task { if aktionen.isEmpty { await load() } }
        .refreshable { await load() }
        .overlay { if loading && aktionen.isEmpty { ProgressView() } }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do { aktionen = try await app.api.getAktionen(); error = nil }
        catch { self.error = "Aktionen konnten nicht geladen werden." }
    }
}

// MARK: - Anfragen

struct AnfragenView: View {
    @EnvironmentObject var app: AppState
    @State private var anfragen: [Anfrage] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            ForEach(anfragen) { a in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(a.type ?? "Anfrage").font(.subheadline)
                        Spacer()
                        Text(a.status ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                    if let by = a.createdBy, !by.isEmpty {
                        Text("\(by) · \(a.createdAt ?? "")").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Anfragen")
        .task { if anfragen.isEmpty { await load() } }
        .refreshable { await load() }
        .overlay {
            if loading && anfragen.isEmpty { ProgressView() }
            else if !loading && anfragen.isEmpty && error == nil {
                ContentUnavailableView("Keine Anfragen", systemImage: "tray")
            }
        }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do { anfragen = try await app.api.getAnfragen(); error = nil }
        catch { self.error = "Anfragen konnten nicht geladen werden." }
    }
}

// MARK: - Benutzer

struct UsersView: View {
    @EnvironmentObject var app: AppState
    @State private var users: [UserInfo] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            ForEach(users) { u in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(u.username).font(.subheadline)
                        if let city = u.city, !city.isEmpty {
                            Text(city).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(u.role ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Benutzer")
        .task { if users.isEmpty { await load() } }
        .refreshable { await load() }
        .overlay { if loading && users.isEmpty { ProgressView() } }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do { users = try await app.api.getUsers(); error = nil }
        catch { self.error = "Benutzer konnten nicht geladen werden." }
    }
}

// MARK: - Punkte (tab)

struct PunkteView: View {
    @EnvironmentObject var app: AppState
    @State private var konto: PunkteKonto?
    @State private var loading = true

    var body: some View {
        VStack(spacing: 12) {
            if loading {
                ProgressView()
            } else {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 56)).foregroundStyle(.yellow)
                Text("\(konto?.gesamt ?? 0)").font(.system(size: 44, weight: .bold))
                Text("Punkte gesamt").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Punkte")
        .task { await load() }
    }

    private func load() async {
        loading = true; defer { loading = false }
        konto = try? await app.api.getPunkteKonto()
    }
}

// MARK: - Einstellungen

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Form {
            if let s = app.session {
                Section("Konto") {
                    LabeledContent("Benutzer", value: s.username)
                    LabeledContent("Rolle", value: s.role)
                    if let a = s.address {
                        let addr = [a.street, [a.plz, a.city].filter { !$0.isEmpty }.joined(separator: " ")]
                            .filter { !$0.isEmpty }.joined(separator: ", ")
                        if !addr.isEmpty { LabeledContent("Adresse", value: addr) }
                    }
                }
            }
            Section("Verbindung") {
                if let name = app.store.serverName { LabeledContent("Server", value: name) }
                LabeledContent("Modus", value: app.store.isExtern ? "Extern (SSH)" : "Lokal")
            }
            Section("App") {
                LabeledContent("Version", value: appVersion)
            }
            Section {
                Button(role: .destructive) { app.logout() } label: { Text("Abmelden") }
            }
        }
        .navigationTitle("Einstellungen")
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}

// MARK: - Update (no APK install on iOS)

struct UpdateView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Installierte Version", value: appVersion)
            }
            Section {
                Text("Updates werden per Sideload/TestFlight installiert — kein direkter APK-Download wie in der Android-App.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Update")
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}

// MARK: - Hex color helper

extension Color {
    init?(hex: String?) {
        guard var h = hex else { return nil }
        h = h.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}
