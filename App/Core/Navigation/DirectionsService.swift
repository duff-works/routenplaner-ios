import Foundation
import RoutenplanerLogic

enum DirectionsError: Error { case status(String) }

/// Calls the Google Directions HTTP API directly (as the Android app does) for the
/// per-step maneuver list the backend strips. Uses the Maps key vended by the backend.
struct DirectionsService {
    let apiKey: String

    struct Result {
        let steps: [NavStep]
        let totalMeters: Int
        let overview: [LatLon]
    }

    func route(origin: LatLon, dest: LatLon, mode: TravelMode,
               language: String = "de", waypoints: [LatLon] = []) async throws -> Result {
        var comps = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!
        var q = [
            URLQueryItem(name: "origin", value: "\(origin.lat),\(origin.lon)"),
            URLQueryItem(name: "destination", value: "\(dest.lat),\(dest.lon)"),
            URLQueryItem(name: "mode", value: mode.rawValue),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "departure_time", value: "now"),
            URLQueryItem(name: "key", value: apiKey),
        ]
        if !waypoints.isEmpty {
            q.append(URLQueryItem(name: "waypoints",
                value: waypoints.map { "via:\($0.lat),\($0.lon)" }.joined(separator: "|")))
        }
        comps.queryItems = q

        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(GDirectionsResponse.self, from: data)
        guard decoded.status == "OK", let leg = decoded.routes.first?.legs.first else {
            throw DirectionsError.status(decoded.status)
        }
        let steps = leg.steps.map { s in
            NavStep(
                instruction: stripHTML(s.htmlInstructions ?? ""),
                distanceMeters: s.distance?.value ?? 0,
                distanceText: s.distance?.text ?? "",
                durationSeconds: s.duration?.value ?? 0,
                maneuver: parseManeuver(s.maneuver),
                polyline: decodePolyline(s.polyline?.points ?? ""),
                startLocation: LatLon(s.startLocation?.lat ?? 0, s.startLocation?.lng ?? 0),
                endLocation: LatLon(s.endLocation?.lat ?? 0, s.endLocation?.lng ?? 0),
                travelMode: mode)
        }
        let overview = decodePolyline(decoded.routes.first?.overviewPolyline?.points ?? "")
        return Result(steps: steps, totalMeters: leg.distance?.value ?? 0, overview: overview)
    }
}

// Google Directions Codable (plain JSONDecoder — explicit CodingKeys for snake_case).
private struct GDirectionsResponse: Decodable {
    let status: String
    let routes: [GRoute]
    let errorMessage: String?
    enum CodingKeys: String, CodingKey { case status, routes; case errorMessage = "error_message" }
}
private struct GRoute: Decodable {
    let legs: [GLeg]
    let overviewPolyline: GPolyline?
    enum CodingKeys: String, CodingKey { case legs; case overviewPolyline = "overview_polyline" }
}
private struct GLeg: Decodable {
    let distance: GTextValue?
    let duration: GTextValue?
    let steps: [GStep]
}
private struct GStep: Decodable {
    let distance: GTextValue?
    let duration: GTextValue?
    let startLocation: GLatLng?
    let endLocation: GLatLng?
    let htmlInstructions: String?
    let maneuver: String?
    let polyline: GPolyline?
    enum CodingKeys: String, CodingKey {
        case distance, duration, maneuver, polyline
        case startLocation = "start_location"
        case endLocation = "end_location"
        case htmlInstructions = "html_instructions"
    }
}
private struct GTextValue: Decodable { let text: String; let value: Int }
private struct GLatLng: Decodable { let lat: Double; let lng: Double }
private struct GPolyline: Decodable { let points: String }
