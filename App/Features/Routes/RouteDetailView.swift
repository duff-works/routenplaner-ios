import SwiftUI

struct RouteDetailView: View {
    let routeId: String
    @EnvironmentObject var app: AppState
    @State private var route: Route?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if let r = route {
                VStack(spacing: 0) {
                    GoogleMapView(pins: stopPins(r), polyline: r.directionsCache?.overviewPolyline)
                        .frame(height: 260)
                    List {
                        if let d = r.directionsCache {
                            Section("Übersicht") {
                                if let dist = d.totalDistanceText, !dist.isEmpty {
                                    LabeledContent("Distanz", value: dist)
                                }
                                if let dur = d.totalDrivingText, !dur.isEmpty {
                                    LabeledContent("Fahrzeit", value: dur)
                                }
                                if let end = d.estimatedEnd, !end.isEmpty {
                                    LabeledContent("Ende (geschätzt)", value: end)
                                }
                            }
                        }
                        Section("Stopps (\(r.stops?.count ?? 0))") {
                            ForEach(Array((r.stops ?? []).enumerated()), id: \.offset) { idx, stop in
                                stopRow(index: idx, stop: stop)
                            }
                        }
                    }
                }
            } else if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle(route?.name ?? "Route")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder private func stopRow(index: Int, stop: RouteStop) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption).bold()
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(stop.customerName ?? stop.freeStopName ?? stop.customerCompany ?? "Stopp")
                    .font(.subheadline)
                if let city = stop.customerCity, !city.isEmpty {
                    Text(city).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if stop.visitStatus == "completed" {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
    }

    private func stopPins(_ r: Route) -> [MapPin] {
        (r.stops ?? []).compactMap { s in
            guard let lat = s.lat, let lon = s.lon, lat != 0 || lon != 0 else { return nil }
            return MapPin(lat: lat, lon: lon,
                          title: s.customerName ?? s.freeStopName ?? "Stopp",
                          snippet: s.customerCity)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            route = try await app.api.getRoute(id: routeId)
            error = nil
        } catch {
            self.error = "Route konnte nicht geladen werden."
        }
    }
}
