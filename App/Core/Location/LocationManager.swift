import Foundation
import CoreLocation

/// CoreLocation for turn-by-turn (analog of Android GpsTrackingService + LocationHelper).
/// Background updates keep it alive screen-off (UIBackgroundModes: location).
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: CLLocationDirection = 0
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    var onLocation: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false  // critical — iOS pauses at stops otherwise
        manager.headingFilter = 2
    }

    func start() {
        requestAuth()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func requestAuth() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
        default: break
        }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        authorization = m.authorizationStatus
        if authorization == .authorizedWhenInUse { m.requestAlwaysAuthorization() }
        // Enable background updates only once granted (setting it without a grant crashes).
        m.allowsBackgroundLocationUpdates =
            (authorization == .authorizedAlways || authorization == .authorizedWhenInUse)
        m.showsBackgroundLocationIndicator = true
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        location = loc
        onLocation?(loc)
    }

    func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        if h.trueHeading >= 0 { heading = h.trueHeading }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        // Keep going, like Android's START_STICKY service.
    }
}
