import Foundation

// ===== Constants (verbatim from Android NavigationViewModel) =====
public enum NavConstants {
    public static let arrivalRadius = 50.0          // ARRIVAL_RADIUS_DRIVING/WALKING
    public static let parkingRadius = 50.0
    public static let offRouteTolerance = 100.0     // OFF_ROUTE_TOLERANCE
    public static let offRouteTicks = 3             // OFF_ROUTE_TICKS
    public static let arrivalDwellTicks = 5         // ARRIVAL_DWELL_TICKS
    public static let stepAdvanceRadius = 30.0      // STEP_ADVANCE_RADIUS
    public static let approachWarningDistance = 200 // metres
    public static let immediateWarningDistance = 30 // metres
    public static let earthRadius = 6371009.0
}

public struct LatLon: Equatable {
    public var lat: Double
    public var lon: Double
    public init(_ lat: Double, _ lon: Double) { self.lat = lat; self.lon = lon }
}

@inline(__always) private func deg2rad(_ d: Double) -> Double { d * .pi / 180 }

/// Great-circle metres (SphericalUtil.computeDistanceBetween).
public func haversineMeters(_ a: LatLon, _ b: LatLon) -> Double {
    let dLat = deg2rad(b.lat - a.lat), dLon = deg2rad(b.lon - a.lon)
    let la1 = deg2rad(a.lat), la2 = deg2rad(b.lat)
    let h = sin(dLat/2)*sin(dLat/2) + cos(la1)*cos(la2)*sin(dLon/2)*sin(dLon/2)
    return 2 * NavConstants.earthRadius * asin(min(1, sqrt(h)))
}

/// Initial bearing in degrees, wrapped to [-180,180] (SphericalUtil.computeHeading).
public func headingDegrees(from a: LatLon, to b: LatLon) -> Double {
    let la1 = deg2rad(a.lat), la2 = deg2rad(b.lat)
    let dLon = deg2rad(b.lon - a.lon)
    let y = sin(dLon) * cos(la2)
    let x = cos(la1)*sin(la2) - sin(la1)*cos(la2)*cos(dLon)
    let deg = atan2(y, x) * 180 / .pi
    return (deg + 540).truncatingRemainder(dividingBy: 360) - 180
}

private func pointToSegment(_ p: (Double, Double), _ a: (Double, Double), _ b: (Double, Double)) -> Double {
    let dx = b.0 - a.0, dy = b.1 - a.1
    let len2 = dx*dx + dy*dy
    let t = len2 == 0 ? 0 : max(0, min(1, ((p.0-a.0)*dx + (p.1-a.1)*dy) / len2))
    let cx = a.0 + t*dx, cy = a.1 + t*dy
    return hypot(p.0 - cx, p.1 - cy)
}

/// Min distance (m) from point to polyline via local equirectangular projection
/// (sub-metre at city scale; faithful stand-in for PolyUtil's spherical cross-track).
public func distanceToPolylineMeters(_ p: LatLon, _ poly: [LatLon]) -> Double {
    guard poly.count >= 1 else { return .infinity }
    if poly.count == 1 { return haversineMeters(p, poly[0]) }
    let mPerDegLat = NavConstants.earthRadius * .pi / 180
    let mPerDegLon = mPerDegLat * cos(deg2rad(p.lat))
    func xy(_ q: LatLon) -> (Double, Double) {
        ((q.lon - p.lon) * mPerDegLon, (q.lat - p.lat) * mPerDegLat)
    }
    var best = Double.infinity
    for i in 0..<(poly.count - 1) {
        best = min(best, pointToSegment((0, 0), xy(poly[i]), xy(poly[i + 1])))
    }
    return best
}

/// PolyUtil.isLocationOnPath(point, polyline, geodesic:true, tolerance).
public func isLocationOnPath(_ p: LatLon, _ poly: [LatLon], tolerance: Double) -> Bool {
    guard !poly.isEmpty else { return false }
    return distanceToPolylineMeters(p, poly) <= tolerance
}

/// True when the fix lies beyond OFF_ROUTE_TOLERANCE of the whole leg polyline.
public func isOffPath(_ fix: LatLon, legPolyline: [LatLon]) -> Bool {
    guard !legPolyline.isEmpty else { return false }
    return !isLocationOnPath(fix, legPolyline, tolerance: NavConstants.offRouteTolerance)
}

/// Google encoded-polyline decoder (equivalent of PolyUtil.decode).
public func decodePolyline(_ encoded: String) -> [LatLon] {
    var coords: [LatLon] = []
    var index = encoded.startIndex
    let end = encoded.endIndex
    var lat = 0, lon = 0
    while index < end {
        func nextValue() -> Int {
            var result = 0, shift = 0, b = 0
            repeat {
                guard index < end else { break }
                b = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (b & 0x1F) << shift
                shift += 5
            } while b >= 0x20
            return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        }
        lat += nextValue()
        lon += nextValue()
        coords.append(LatLon(Double(lat) / 1e5, Double(lon) / 1e5))
    }
    return coords
}

// ===== Nav models (mirror Android NavigationModels) =====

public enum TravelMode: String, Equatable { case driving, bicycling, walking }

public enum Maneuver: Equatable {
    case turnLeft, turnRight, turnSlightLeft, turnSlightRight, turnSharpLeft, turnSharpRight
    case turnU, straight, merge, forkLeft, forkRight, rampLeft, rampRight
    case keepLeft, keepRight, roundaboutLeft, roundaboutRight, arrive, depart, unknown
}

public func parseManeuver(_ s: String?) -> Maneuver {
    switch s {
    case "turn-left": return .turnLeft
    case "turn-right": return .turnRight
    case "turn-slight-left": return .turnSlightLeft
    case "turn-slight-right": return .turnSlightRight
    case "turn-sharp-left": return .turnSharpLeft
    case "turn-sharp-right": return .turnSharpRight
    case "uturn-left", "uturn-right": return .turnU
    case "straight": return .straight
    case "merge": return .merge
    case "fork-left": return .forkLeft
    case "fork-right": return .forkRight
    case "ramp-left": return .rampLeft
    case "ramp-right": return .rampRight
    case "keep-left": return .keepLeft
    case "keep-right": return .keepRight
    case "roundabout-left": return .roundaboutLeft
    case "roundabout-right": return .roundaboutRight
    default: return .unknown
    }
}

/// Strip HTML tags + decode the few entities Directions uses (Foundation-safe; Android used Html.fromHtml).
public func stripHTML(_ html: String) -> String {
    var s = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"]
    for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

public struct NavStep: Equatable {
    public let instruction: String
    public let distanceMeters: Int
    public let distanceText: String
    public let durationSeconds: Int
    public let maneuver: Maneuver
    public let polyline: [LatLon]
    public let startLocation: LatLon
    public let endLocation: LatLon
    public let travelMode: TravelMode
    public init(instruction: String, distanceMeters: Int, distanceText: String, durationSeconds: Int,
                maneuver: Maneuver, polyline: [LatLon], startLocation: LatLon, endLocation: LatLon,
                travelMode: TravelMode) {
        self.instruction = instruction; self.distanceMeters = distanceMeters
        self.distanceText = distanceText; self.durationSeconds = durationSeconds
        self.maneuver = maneuver; self.polyline = polyline
        self.startLocation = startLocation; self.endLocation = endLocation; self.travelMode = travelMode
    }
}

public struct NavTarget: Equatable {
    public let destination: LatLon
    public let parking: LatLon?
    public let name: String
    public var hasParkingCoords: Bool { parking != nil }
    public init(destination: LatLon, parking: LatLon?, name: String) {
        self.destination = destination; self.parking = parking; self.name = name
    }
}

public struct LocationFix: Equatable {
    public let coord: LatLon
    public let bearing: Double?
    public let speed: Double
    public init(coord: LatLon, bearing: Double?, speed: Double) {
        self.coord = coord; self.bearing = bearing; self.speed = speed
    }
}

// ===== Step math (pure) =====

public struct StepAdvanceResult: Equatable {
    public let newIndex: Int
    public let distanceToManeuver: Int
    public let crossedStep: Bool
}

/// Advance the current step while within STEP_ADVANCE_RADIUS of its end (can skip several).
public func advanceStep(fix: LatLon, steps: [NavStep], from index: Int) -> StepAdvanceResult {
    guard index < steps.count else { return .init(newIndex: index, distanceToManeuver: 0, crossedStep: false) }
    var idx = index
    var crossed = false
    while idx < steps.count - 1 {
        let d = Int(haversineMeters(fix, steps[idx].endLocation))
        if Double(d) < NavConstants.stepAdvanceRadius { idx += 1; crossed = true } else { break }
    }
    let dist = Int(haversineMeters(fix, steps[idx].endLocation))
    return .init(newIndex: idx, distanceToManeuver: dist, crossedStep: crossed)
}

/// Choose the starting step after (re)applying directions (skips steps already behind).
public func initialStepIndex(fix: LatLon?, steps: [NavStep]) -> Int {
    guard let fix, steps.count > 1 else { return 0 }
    var start = 0
    for i in steps.indices {
        if Double(Int(haversineMeters(fix, steps[i].endLocation))) < NavConstants.stepAdvanceRadius {
            start = min(i + 1, steps.count - 1)
        } else { break }
    }
    return start
}
