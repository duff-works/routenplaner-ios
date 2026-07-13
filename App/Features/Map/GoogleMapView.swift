import SwiftUI
import GoogleMaps

struct MapPin: Identifiable {
    let id = UUID()
    let lat: Double
    let lon: Double
    let title: String
    let snippet: String?
}

/// SwiftUI wrapper around GMSMapView (Google Maps iOS SDK). Mirrors the Android
/// LiveMapComposable: shows status-neutral customer pins and fits them in view.
struct GoogleMapView: UIViewRepresentable {
    var pins: [MapPin]

    func makeUIView(context: Context) -> GMSMapView {
        // Default camera on Switzerland; replaced by the fit-to-pins below.
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition.camera(withLatitude: 47.3769, longitude: 8.5417, zoom: 7)
        return GMSMapView(options: options)
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        map.clear()
        guard !pins.isEmpty else { return }
        var bounds = GMSCoordinateBounds()
        for pin in pins {
            let position = CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon)
            let marker = GMSMarker(position: position)
            marker.title = pin.title
            marker.snippet = pin.snippet
            marker.map = map
            bounds = bounds.includingCoordinate(position)
        }
        map.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 48))
    }
}
