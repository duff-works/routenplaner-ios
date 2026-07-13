import SwiftUI
import GoogleMaps
import CoreLocation
import RoutenplanerLogic

/// Full-screen navigation map: draws the route line, a heading-rotated puck, and
/// follows the user (camera bearing/tilt/zoom) — mirrors Android NavMapComposable.
struct NavMapView: UIViewRepresentable {
    var location: CLLocation?
    var bearing: Double
    var walking: Bool
    var routePolyline: [LatLon]

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition.camera(withLatitude: 47.3769, longitude: 8.5417, zoom: 15)
        let map = GMSMapView(options: options)
        map.isMyLocationEnabled = false
        map.settings.compassButton = true
        map.settings.tiltGestures = false
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        map.clear()

        if routePolyline.count > 1 {
            let path = GMSMutablePath()
            for p in routePolyline {
                path.add(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon))
            }
            let line = GMSPolyline(path: path)
            line.strokeWidth = 6
            line.strokeColor = UIColor(red: 0.16, green: 0.47, blue: 1.0, alpha: 1.0) // 2979FF
            line.map = map
        }

        guard let loc = location else { return }
        let coord = loc.coordinate

        let puck = GMSMarker(position: coord)
        puck.isFlat = true
        puck.rotation = bearing
        puck.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        puck.icon = GMSMarker.markerImage(with: .systemBlue)
        puck.map = map

        let camera = GMSCameraPosition(target: coord,
                                       zoom: walking ? 18 : 17,
                                       bearing: bearing,
                                       viewingAngle: walking ? 30 : 60)
        CATransaction.begin()
        CATransaction.setValue(0.5, forKey: kCATransactionAnimationDuration)
        map.animate(to: camera)
        CATransaction.commit()
    }
}
