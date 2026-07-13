import SwiftUI
import GoogleMaps

struct MapPin: Identifiable {
    let id = UUID()
    let lat: Double
    let lon: Double
    let title: String
    let snippet: String?
}

/// SwiftUI wrapper around GMSMapView (Google Maps iOS SDK). Shows customer/stop pins
/// and, optionally, an encoded route polyline (directions_cache.overview_polyline).
struct GoogleMapView: UIViewRepresentable {
    var pins: [MapPin]
    var polyline: String? = nil

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition.camera(withLatitude: 47.3769, longitude: 8.5417, zoom: 7)
        return GMSMapView(options: options)
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        map.clear()
        var bounds = GMSCoordinateBounds()
        var hasContent = false

        if let encoded = polyline, !encoded.isEmpty, let path = GMSPath(fromEncodedPath: encoded) {
            let line = GMSPolyline(path: path)
            line.strokeWidth = 4
            line.strokeColor = .systemBlue
            line.map = map
            bounds = bounds.includingPath(path)
            hasContent = true
        }
        for pin in pins {
            let position = CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon)
            let marker = GMSMarker(position: position)
            marker.title = pin.title
            marker.snippet = pin.snippet
            marker.map = map
            bounds = bounds.includingCoordinate(position)
            hasContent = true
        }
        if hasContent {
            map.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 48))
        }
    }
}
