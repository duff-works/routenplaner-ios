import Foundation
import CoreLocation
import RoutenplanerLogic

/// Orchestrates the pure NavigationEngine with CoreLocation, the Directions HTTP API,
/// German TTS, and throttled backend GPS reporting.
@MainActor
final class NavigationViewModel: ObservableObject {
    @Published var snapshot = NavigationSnapshot()
    @Published var routePolyline: [LatLon] = []
    @Published var location: CLLocation?
    @Published var bearing: Double = 0
    @Published var errorMessage: String?
    @Published var isActive = false

    private let engine = NavigationEngine()
    private let locationManager = LocationManager()
    private let announcer = SpeechAnnouncer()
    private var directions: DirectionsService?

    private let api: APIClient
    private let routeId: String?
    private let target: NavTarget
    private var lastGpsPost = Date.distantPast

    init(api: APIClient, routeId: String?, target: NavTarget) {
        self.api = api
        self.routeId = routeId
        self.target = target
        locationManager.onLocation = { [weak self] loc in
            Task { @MainActor in self?.onLocation(loc) }
        }
    }

    func start() async {
        guard !isActive else { return }
        isActive = true
        let backendKey = try? await api.getMapsKey()
        let key = backendKey
            ?? (Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String ?? "")
        directions = DirectionsService(apiKey: key)
        engine.startLeg(target: target, mode: .driving, isReturnLeg: false)
        snapshot = engine.snapshot
        locationManager.start()
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        locationManager.stop()
        engine.stop()
        announcer.shutdown()
        snapshot = engine.snapshot
        Task { await api.gpsStop() }
    }

    private func onLocation(_ loc: CLLocation) {
        location = loc
        let fix = LocationFix(coord: LatLon(loc.coordinate.latitude, loc.coordinate.longitude),
                              bearing: loc.course >= 0 ? loc.course : nil,
                              speed: max(0, loc.speed))
        let effects = engine.update(location: fix)
        snapshot = engine.snapshot
        bearing = engine.snapshot.bearing
        handle(effects, fix: fix)
        reportGps(loc)
    }

    private func handle(_ effects: [NavigationEffect], fix: LocationFix) {
        for e in effects {
            switch e {
            case .announce(let text):
                announcer.announce(text)
            case .needsDirections(let dest, let mode, _):
                Task { await fetchDirections(dest: dest, mode: mode, fix: fix) }
            case .reachedParking, .arrivedAtStop:
                break
            }
        }
    }

    private func fetchDirections(dest: LatLon, mode: TravelMode, fix: LocationFix) async {
        guard let directions else { return }
        do {
            let result = try await directions.route(origin: fix.coord, dest: dest, mode: mode)
            let legPoly = result.steps.flatMap { $0.polyline }
            routePolyline = result.overview.isEmpty ? legPoly : result.overview
            let effects = engine.applyDirections(steps: result.steps, legPolyline: legPoly,
                                                 mode: mode, totalDistanceMeters: result.totalMeters,
                                                 fix: fix.coord)
            snapshot = engine.snapshot
            handle(effects, fix: fix)
        } catch {
            errorMessage = "Route konnte nicht berechnet werden."
        }
    }

    private func reportGps(_ loc: CLLocation) {
        let now = Date()
        guard now.timeIntervalSince(lastGpsPost) >= 5 else { return }  // BACKEND_UPDATE_INTERVAL_MS
        lastGpsPost = now
        Task {
            await api.gpsUpdate(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude,
                                accuracy: loc.horizontalAccuracy,
                                speed: loc.speed >= 0 ? loc.speed : nil,
                                heading: loc.course >= 0 ? loc.course : nil,
                                routeId: routeId)
        }
    }
}
