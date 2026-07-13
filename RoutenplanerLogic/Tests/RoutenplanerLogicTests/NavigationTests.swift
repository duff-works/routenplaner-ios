import XCTest
@testable import RoutenplanerLogic

final class NavigationGeometryTests: XCTestCase {
    func testHaversineKnownPair() {
        // ~1113 m north (0.01 deg lat)
        let d = haversineMeters(LatLon(47.0, 8.0), LatLon(47.01, 8.0))
        XCTAssertEqual(d, 1113, accuracy: 5)
    }

    func testIsLocationOnPathBoundary() {
        let line = [LatLon(47.0, 8.0), LatLon(47.01, 8.0)]
        // ~38 m east of the line -> on path (tol 100)
        XCTAssertTrue(isLocationOnPath(LatLon(47.005, 8.0005), line, tolerance: 100))
        // ~228 m east -> off path
        XCTAssertFalse(isLocationOnPath(LatLon(47.005, 8.003), line, tolerance: 100))
    }

    func testDecodePolylineKnownExample() {
        // Google's documented example decodes to (38.5,-120.2),(40.7,-120.95),(43.252,-126.453)
        let pts = decodePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(pts.count, 3)
        XCTAssertEqual(pts[0].lat, 38.5, accuracy: 0.001)
        XCTAssertEqual(pts[0].lon, -120.2, accuracy: 0.001)
        XCTAssertEqual(pts[2].lat, 43.252, accuracy: 0.001)
    }

    func testParseManeuver() {
        XCTAssertEqual(parseManeuver("turn-left"), .turnLeft)
        XCTAssertEqual(parseManeuver("uturn-right"), .turnU)
        XCTAssertEqual(parseManeuver("something-else"), .unknown)
    }

    func testStripHTML() {
        XCTAssertEqual(stripHTML("Turn <b>left</b> onto Main&nbsp;St"), "Turn left onto Main St")
    }
}

final class NavigationEngineTests: XCTestCase {
    private let A = LatLon(47.0, 8.0)
    private let B = LatLon(47.01, 8.0)
    private let onPath = LatLon(47.005, 8.0005)   // ~38 m off
    private let offPath = LatLon(47.005, 8.003)   // ~228 m off

    private func oneStep() -> [NavStep] {
        [NavStep(instruction: "Geradeaus", distanceMeters: 1113, distanceText: "1,1 km",
                 durationSeconds: 120, maneuver: .straight, polyline: [A, B],
                 startLocation: A, endLocation: B, travelMode: .driving)]
    }

    private func drivingEngine(parking: LatLon? = nil) -> NavigationEngine {
        let engine = NavigationEngine()
        let target = NavTarget(destination: B, parking: parking, name: "Test")
        engine.startLeg(target: target, mode: .driving, isReturnLeg: false)
        _ = engine.update(location: LocationFix(coord: A, bearing: nil, speed: 10))  // triggers needsDirections
        let dest = parking ?? B
        let steps = [NavStep(instruction: "Geradeaus", distanceMeters: 1000, distanceText: "1 km",
                             durationSeconds: 120, maneuver: .straight, polyline: [A, dest],
                             startLocation: A, endLocation: dest, travelMode: .driving)]
        _ = engine.applyDirections(steps: steps, legPolyline: [A, dest], mode: .driving,
                                   totalDistanceMeters: 1000, fix: A)
        return engine
    }

    func testStartLegRequestsDirectionsOnFirstFix() {
        let engine = NavigationEngine()
        engine.startLeg(target: NavTarget(destination: B, parking: nil, name: "X"), mode: .driving, isReturnLeg: false)
        XCTAssertEqual(engine.snapshot.navState, .calculating)
        let effects = engine.update(location: LocationFix(coord: A, bearing: nil, speed: 5))
        XCTAssertTrue(effects.contains { if case .needsDirections = $0 { return true }; return false })
    }

    func testApplyDirectionsEntersDrivingToStop() {
        let engine = drivingEngine()
        XCTAssertEqual(engine.snapshot.navState, .drivingToStop)
    }

    func testOffRouteRequiresThreeTicks() {
        let engine = drivingEngine()
        let off = LocationFix(coord: offPath, bearing: nil, speed: 10)
        _ = engine.update(location: off)
        XCTAssertEqual(engine.snapshot.navState, .drivingToStop)
        _ = engine.update(location: off)
        XCTAssertEqual(engine.snapshot.navState, .drivingToStop)
        let e3 = engine.update(location: off)
        XCTAssertEqual(engine.snapshot.navState, .offRoute)
        XCTAssertTrue(engine.snapshot.isOffRoute)
        XCTAssertTrue(e3.contains { if case .announce = $0 { return true }; return false })
    }

    func testOffRouteThenNextTickReroutes() {
        let engine = drivingEngine()
        let off = LocationFix(coord: offPath, bearing: nil, speed: 10)
        for _ in 1...3 { _ = engine.update(location: off) }
        XCTAssertEqual(engine.snapshot.navState, .offRoute)
        let e4 = engine.update(location: off)
        XCTAssertEqual(engine.snapshot.navState, .rerouting)
        XCTAssertTrue(e4.contains { if case .needsDirections(_, _, let r) = $0 { return r == .reroute }; return false })
    }

    func testOffRouteResetsOnReturnToPath() {
        let engine = drivingEngine()
        let off = LocationFix(coord: offPath, bearing: nil, speed: 10)
        _ = engine.update(location: off)
        _ = engine.update(location: off)
        _ = engine.update(location: LocationFix(coord: onPath, bearing: nil, speed: 10))
        XCTAssertEqual(engine.snapshot.navState, .drivingToStop)
        XCTAssertFalse(engine.snapshot.isOffRoute)
    }

    func testStepAdvanceWithin30m() {
        let engine = NavigationEngine()
        let M = LatLon(47.005, 8.0)
        engine.startLeg(target: NavTarget(destination: B, parking: nil, name: "X"), mode: .driving, isReturnLeg: false)
        _ = engine.update(location: LocationFix(coord: A, bearing: nil, speed: 10))
        let steps = [
            NavStep(instruction: "Schritt 1", distanceMeters: 550, distanceText: "", durationSeconds: 60,
                    maneuver: .straight, polyline: [A, M], startLocation: A, endLocation: M, travelMode: .driving),
            NavStep(instruction: "Schritt 2", distanceMeters: 550, distanceText: "", durationSeconds: 60,
                    maneuver: .straight, polyline: [M, B], startLocation: M, endLocation: B, travelMode: .driving),
        ]
        _ = engine.applyDirections(steps: steps, legPolyline: [A, M, B], mode: .driving,
                                   totalDistanceMeters: 1100, fix: A)
        XCTAssertEqual(engine.snapshot.currentStepIndex, 0)
        // ~7.6 m from M -> advance to step 1
        _ = engine.update(location: LocationFix(coord: LatLon(47.005, 8.0001), bearing: nil, speed: 10))
        XCTAssertEqual(engine.snapshot.currentStepIndex, 1)
    }

    func testArrivalRequiresFiveDwellTicks() {
        let engine = drivingEngine()
        let atB = LocationFix(coord: B, bearing: nil, speed: 1)
        for _ in 1...4 {
            _ = engine.update(location: atB)
            XCTAssertEqual(engine.snapshot.navState, .drivingToStop)
        }
        let e5 = engine.update(location: atB)
        XCTAssertEqual(engine.snapshot.navState, .arrived)
        XCTAssertTrue(e5.contains { if case .arrivedAtStop = $0 { return true }; return false })
    }

    func testParkingSingleTickTransitionToWalking() {
        let P = LatLon(47.008, 8.0)
        let engine = drivingEngine(parking: P)
        XCTAssertEqual(engine.snapshot.navState, .drivingToParking)
        let atP = LocationFix(coord: P, bearing: nil, speed: 2)
        let e = engine.update(location: atP)
        XCTAssertEqual(engine.snapshot.navState, .calculating)
        XCTAssertTrue(e.contains { if case .needsDirections(_, let m, let r) = $0 { return m == .walking && r == .parkingToCustomerWalk }; return false })
    }
}
