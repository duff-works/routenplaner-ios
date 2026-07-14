import SwiftUI
import UIKit

// MARK: - Dashboard API models (decoded via getJSON + .convertFromSnakeCase; all optional)

struct DashboardStats: Codable {
    var totalCustomers: Int?
    var withCoordinates: Int?
    var overdueVisits: Int?
    var upcomingVisits: Int?
}

struct MapPinDTO: Codable {
    var lat: Double?
    var lon: Double?
    var name: String?
    var company: String?
    var city: String?
    var status: String?
}
struct MapPinsResponse: Codable { var pins: [MapPinDTO]? }

struct UpcomingRoute: Codable, Identifiable {
    var id: String = ""
    var name: String?
    var date: String?
    var stopCount: Int?
    var status: String?
}
struct UpcomingRoutesResponse: Codable { var routes: [UpcomingRoute]?; var total: Int? }

struct RecentVisit: Codable, Identifiable {
    var id: String = ""
    var customerName: String?
    var date: String?
    var ausgabeCount: Int?
}
struct RecentVisitsResponse: Codable { var recent: [RecentVisit]? }

struct HeuteResponse: Codable {
    var route: HeuteRoute?
    var pendenzen: [Pendenz]?
    var punkte: PunkteSummary?
    var eva: [EvaVorschlag]?
}
struct PunkteSummary: Codable { var periode: Int?; var gesamt: Int? }
struct HeuteRoute: Codable, Identifiable {
    var id: String = ""
    var name: String?
    var status: String?
    var stops: [HeuteRouteStop]?
}
struct HeuteRouteStop: Codable { var visitStatus: String? }
struct Pendenz: Codable, Identifiable {
    var id: String = ""
    var text: String?
    var due: String?
}
struct EvaVorschlag: Codable, Identifiable {
    var id: String = ""
    var titel: String?
    var text: String?
    var quelle: String?
    var typ: String?
}

// MARK: - ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    private let api: APIClient
    init(api: APIClient) { self.api = api }

    @Published var isLoading = true
    @Published var stats: DashboardStats?
    @Published var upcomingRoutes: [UpcomingRoute] = []
    @Published var recentVisits: [RecentVisit] = []
    @Published var mapPins: [MapPin] = []

    @Published var heuteLoading = true
    @Published var heuteError: String?
    @Published var heuteRoute: HeuteRoute?
    @Published var pendenzen: [Pendenz] = []
    @Published var eva: [EvaVorschlag] = []
    @Published var punkte = PunkteSummary(periode: 0, gesamt: 0)

    private static let statusOrder = ["in_progress": 0, "planned": 1, "completed": 2]

    func load() async {
        async let a: Void = loadDashboard()
        async let b: Void = loadHeute()
        _ = await (a, b)
    }

    func loadDashboard() async {
        isLoading = true
        stats = try? await api.getDashboardStats()
        let routes = (try? await api.getUpcomingRoutes()) ?? []
        upcomingRoutes = routes.sorted {
            (Self.statusOrder[$0.status ?? "planned"] ?? 1) < (Self.statusOrder[$1.status ?? "planned"] ?? 1)
        }
        recentVisits = (try? await api.getRecentVisits()) ?? []
        let dtos = (try? await api.getMapPins()) ?? []
        mapPins = dtos.compactMap { d in
            guard let lat = d.lat, let lon = d.lon, lat != 0 || lon != 0 else { return nil }
            return MapPin(lat: lat, lon: lon, title: d.company ?? d.name ?? "", snippet: d.city)
        }
        isLoading = false
    }

    func loadHeute() async {
        heuteLoading = true
        heuteError = nil
        do {
            let h = try await api.getHeute()
            heuteRoute = h.route
            pendenzen = h.pendenzen ?? []
            eva = h.eva ?? []
            punkte = h.punkte ?? PunkteSummary(periode: 0, gesamt: 0)
        } catch {
            heuteError = "Konnte nicht geladen werden."
        }
        heuteLoading = false
    }
}

// MARK: - Screen

struct DashboardView: View {
    @StateObject private var vm: DashboardViewModel
    init(api: APIClient) { _vm = StateObject(wrappedValue: DashboardViewModel(api: api)) }

    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heuteSection
                if !vm.eva.isEmpty { evaSection }
                if !vm.pendenzen.isEmpty { pendenzenSection }
                punkteSection
                statsSection
                if !vm.upcomingRoutes.isEmpty { upcomingSection }
                if !vm.recentVisits.isEmpty { recentSection }
                mapSection
            }
            .padding(16)
            .frame(maxWidth: isPhone ? .infinity : 700)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Heute")
        .navigationDestination(for: String.self) { id in RouteDetailView(routeId: id) }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    @ViewBuilder private var heuteSection: some View {
        if vm.heuteLoading {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 16)
        } else {
            HeuteCard(route: vm.heuteRoute)
        }
    }

    private var evaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("EVA-Vorschläge")
            ForEach(vm.eva) { EvaCardView(titel: $0.titel ?? "", text: $0.text ?? "", quelle: $0.quelle ?? "") }
        }
    }

    private var pendenzenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Pendenzen")
            ForEach(vm.pendenzen) { PendenzRow(pendenz: $0) }
        }
    }

    private var punkteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Punkte")
            HStack(spacing: 8) {
                PointsChip(points: vm.punkte.periode ?? 0)
                PointsChip(points: vm.punkte.gesamt ?? 0, label: "Gesamt")
            }
        }
    }

    private var statsSection: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: isPhone ? 2 : 4)
        return LazyVGrid(columns: cols, spacing: 8) {
            StatsCard(title: "Gesamt", value: vm.stats?.totalCustomers ?? 0)
            StatsCard(title: "Mit Koord.", value: vm.stats?.withCoordinates ?? 0, color: .green)
            StatsCard(title: "Überfällig", value: vm.stats?.overdueVisits ?? 0, color: .red)
            StatsCard(title: "Bald fällig", value: vm.stats?.upcomingVisits ?? 0, color: .orange)
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Nächste Routen")
            ForEach(vm.upcomingRoutes) { r in
                NavigationLink(value: r.id) { UpcomingRouteRow(route: r) }.buttonStyle(.plain)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Letzte Besuche")
            ForEach(vm.recentVisits) { RecentVisitRow(visit: $0) }
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Karte")
            GoogleMapView(pins: vm.mapPins)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Pieces

private struct SectionTitle: View {
    let t: String
    init(_ t: String) { self.t = t }
    var body: some View { Text(t).font(.headline) }
}

struct StatsCard: View {
    let title: String
    let value: Int
    var color: Color = .primary
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.system(size: 26, weight: .medium)).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 1))
    }
}

struct PointsChip: View {
    let points: Int
    var label: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "medal.fill").font(.system(size: 13)).foregroundStyle(Color.kcGold)
            Text("\(points)").font(.callout).bold().monospacedDigit().foregroundStyle(.white)
            if let label { Text(label).font(.caption2).foregroundStyle(.white.opacity(0.85)) }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Color.kcAnthracite))
    }
}

struct HeuteCard: View {
    let route: HeuteRoute?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heute").font(.headline)
            if let r = route {
                let gesamt = r.stops?.count ?? 0
                let erledigt = r.stops?.filter { $0.visitStatus == "completed" }.count ?? 0
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name ?? "").font(.subheadline).bold()
                        Text("\(erledigt) von \(gesamt) erledigt").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    NavigationLink("Öffnen", value: r.id).buttonStyle(.borderedProminent)
                }
            } else {
                Text("Keine Route heute").font(.subheadline).foregroundStyle(.secondary)
                Text("Die Routenplanung erfolgt im Intranet-Assistenten.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

struct EvaCardView: View {
    let titel: String
    let text: String
    let quelle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(Color.kcGold700)
                    Text("EVA-VORSCHLAG").font(.caption2).bold().kerning(0.8).foregroundStyle(Color.kcGold700)
                }
                Spacer()
                Text(quelle).font(.caption2).foregroundStyle(.secondary)
            }
            Text(titel).font(.subheadline)
            Text(text).font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.kcGold050))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.kcGold300, lineWidth: 1))
    }
}

struct PendenzRow: View {
    let pendenz: Pendenz
    private var dueLabel: String {
        pendenz.due == "next_visit" ? "Fällig: nächster Besuch" : "Fällig am \(pendenz.due ?? "")"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pendenz.text ?? "").font(.subheadline)
            Text(dueLabel).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

struct UpcomingRouteRow: View {
    let route: UpcomingRoute
    private var badge: (String, Color) {
        switch route.status {
        case "in_progress": return ("Aktiv", .orange)
        case "completed": return ("Fertig", .green)
        default: return ("Geplant", .secondary)
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "map").foregroundStyle(Color.kcGold).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(route.name ?? "").font(.subheadline).bold()
                Text("\(route.date ?? "") · \(route.stopCount ?? 0) Stopps").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(badge.0).font(.caption2).foregroundStyle(badge.1)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .contentShape(Rectangle())
    }
}

struct RecentVisitRow: View {
    let visit: RecentVisit
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.customerName ?? "").font(.subheadline).bold()
                Text(visit.date ?? "").font(.caption).foregroundStyle(.secondary)
                if (visit.ausgabeCount ?? 0) > 0 {
                    Text("\(visit.ausgabeCount ?? 0) Ausgaben").font(.caption2).foregroundStyle(Color.kcGold)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
