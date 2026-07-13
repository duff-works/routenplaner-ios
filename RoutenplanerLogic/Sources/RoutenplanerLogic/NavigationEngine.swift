import Foundation

public enum NavigationState: Equatable {
    case idle, calculating, drivingToStop, drivingToParking, walkingToCustomer, arrived, offRoute, rerouting
}

public enum DirectionsReason: Equatable { case initialLeg, reroute, parkingToCustomerWalk }

public enum NavigationEffect: Equatable {
    case announce(String)
    case needsDirections(destination: LatLon, mode: TravelMode, reason: DirectionsReason)
    case reachedParking(notes: String?)
    case arrivedAtStop(isReturnLeg: Bool)
}

public struct NavigationSnapshot: Equatable {
    public var navState: NavigationState = .idle
    public var currentStepIndex: Int = 0
    public var currentInstruction: String?
    public var nextInstruction: String?
    public var maneuver: Maneuver?
    public var distanceToNextManeuver: Int = 0
    public var distanceToDestination: Int = 0
    public var isOffRoute: Bool = false
    public var travelMode: TravelMode = .driving
    public var bearing: Double = 0
}

/// Pure, synchronous navigation state machine. Does NO I/O — `update(location:)` returns
/// effects (announcements, direction fetches, arrival hooks) the ViewModel executes.
/// Ported 1:1 from Android NavigationViewModel; see Navigation.swift for constants.
public final class NavigationEngine {
    public private(set) var snapshot = NavigationSnapshot()

    private var steps: [NavStep] = []
    private var legPolyline: [LatLon] = []
    private var target: NavTarget?
    private var mode: TravelMode = .driving
    private var isReturnLeg = false

    private var offRouteCounter = 0
    private var arrivalDwellCounter = 0
    private var approachWarned = false
    private var immediateWarned = false
    private var parkingReached = false
    private var pendingDirectionsFetch = false

    public init() {}

    // MARK: Public API

    /// Begin a leg toward `target`. Directions are fetched on the first GPS tick (needs an origin).
    public func startLeg(target: NavTarget, mode: TravelMode, isReturnLeg: Bool) {
        self.target = target
        self.mode = mode
        self.isReturnLeg = isReturnLeg
        parkingReached = false
        resetCounters()
        snapshot.navState = .calculating
        snapshot.isOffRoute = false
        snapshot.travelMode = mode
        pendingDirectionsFetch = true
    }

    /// Apply a fetched Directions result (processDirectionsResponse). Resets counters,
    /// rebuilds steps, picks the resulting state, returns the first announcement.
    public func applyDirections(steps: [NavStep], legPolyline: [LatLon], mode: TravelMode,
                                totalDistanceMeters: Int, fix: LatLon?) -> [NavigationEffect] {
        let wasOffRoute = snapshot.isOffRoute || offRouteCounter > 0
        resetCounters()
        snapshot.isOffRoute = false
        self.steps = steps
        self.legPolyline = legPolyline
        self.mode = mode
        snapshot.currentStepIndex = initialStepIndex(fix: fix, steps: steps)
        snapshot.distanceToDestination = totalDistanceMeters

        if mode == .walking {
            snapshot.navState = .walkingToCustomer
        } else if target?.hasParkingCoords == true && !parkingReached {
            snapshot.navState = .drivingToParking
        } else {
            snapshot.navState = .drivingToStop
        }
        if let fix { refreshInstructions(fix: fix) } else { refreshInstructions() }

        let firstInstr = firstAnnouncedInstruction()
        let msg = wasOffRoute ? "Neue Route berechnet. \(firstInstr)" : "Navigation gestartet. \(firstInstr)"
        return [.announce(msg)]
    }

    /// One GPS tick — the core method. Mirrors onLocationUpdate's `when(navState)`.
    public func update(location fix: LocationFix) -> [NavigationEffect] {
        updateBearing(fix)
        switch snapshot.navState {
        case .idle:
            return []
        case .calculating:
            if pendingDirectionsFetch {
                pendingDirectionsFetch = false
                return [.needsDirections(destination: legDestination(), mode: legMode(), reason: .initialLeg)]
            }
            return []
        case .drivingToStop:
            var e = checkOffRoute(fix.coord)
            e += advanceStepAndWarn(fix.coord)
            e += checkArrival(fix.coord)
            return e
        case .drivingToParking:
            var e = checkParkingArrival(fix.coord)
            if !parkingReached { e += checkOffRoute(fix.coord) }
            e += advanceStepAndWarn(fix.coord)
            return e
        case .walkingToCustomer:
            var e = advanceStepAndWarn(fix.coord)
            e += checkArrival(fix.coord)
            return e
        case .arrived:
            return []
        case .offRoute:
            offRouteCounter += 1
            if offRouteCounter >= NavConstants.offRouteTicks {
                snapshot.navState = .rerouting
                return [.announce("Neuberechnung der Route..."),
                        .needsDirections(destination: legDestination(), mode: legMode(), reason: .reroute)]
            }
            return []
        case .rerouting:
            return []
        }
    }

    /// User tapped "next stop": fire depart + start the next leg's directions.
    public func startNextLeg(target: NavTarget, mode: TravelMode, isReturnLeg: Bool) -> [NavigationEffect] {
        startLeg(target: target, mode: mode, isReturnLeg: isReturnLeg)
        return []
    }

    public func stop() {
        steps = []; legPolyline = []; target = nil; mode = .driving; isReturnLeg = false
        resetCounters(); parkingReached = false; pendingDirectionsFetch = false
        snapshot = NavigationSnapshot()
    }

    // MARK: Internals

    private func resetCounters() {
        offRouteCounter = 0; arrivalDwellCounter = 0; approachWarned = false; immediateWarned = false
    }

    private func legDestination() -> LatLon {
        guard let target else { return LatLon(0, 0) }
        if parkingReached { return target.destination }
        if target.hasParkingCoords && mode != .walking { return target.parking! }
        return target.destination
    }

    private func legMode() -> TravelMode { parkingReached ? .walking : mode }

    private func checkOffRoute(_ fix: LatLon) -> [NavigationEffect] {
        guard !legPolyline.isEmpty else { return [] }
        if isOffPath(fix, legPolyline: legPolyline) {
            offRouteCounter += 1
            if offRouteCounter >= NavConstants.offRouteTicks {
                snapshot.navState = .offRoute
                snapshot.isOffRoute = true
                return [.announce("Route verlassen. Neuberechnung...")]
            }
        } else {
            offRouteCounter = 0
            if snapshot.isOffRoute { snapshot.isOffRoute = false }
        }
        return []
    }

    private func advanceStepAndWarn(_ fix: LatLon) -> [NavigationEffect] {
        guard !steps.isEmpty else { return [] }
        let result = advanceStep(fix: fix, steps: steps, from: snapshot.currentStepIndex)
        if result.crossedStep { approachWarned = false; immediateWarned = false }
        snapshot.currentStepIndex = result.newIndex
        snapshot.distanceToNextManeuver = result.distanceToManeuver
        refreshInstructions(fix: fix)

        var effects: [NavigationEffect] = []
        let nextIdx = min(snapshot.currentStepIndex + 1, steps.count - 1)
        let nextInstr = steps[nextIdx].instruction
        let d = result.distanceToManeuver
        if d > NavConstants.immediateWarningDistance && d <= NavConstants.approachWarningDistance && !approachWarned {
            effects.append(.announce("In \(d) Metern, \(nextInstr)"))
            approachWarned = true
        }
        if d <= NavConstants.immediateWarningDistance && !immediateWarned {
            effects.append(.announce("Jetzt \(nextInstr)"))
            immediateWarned = true
        }
        return effects
    }

    private func checkArrival(_ fix: LatLon) -> [NavigationEffect] {
        guard let target else { return [] }
        let d = haversineMeters(fix, target.destination)
        snapshot.distanceToDestination = Int(d)
        if d < NavConstants.arrivalRadius {
            arrivalDwellCounter += 1
            if arrivalDwellCounter >= NavConstants.arrivalDwellTicks {
                snapshot.navState = .arrived
                let msg = isReturnLeg
                    ? "Sie sind angekommen. Route abgeschlossen."
                    : "Sie haben Ihr Ziel erreicht. \(target.name)"
                return [.announce(msg), .arrivedAtStop(isReturnLeg: isReturnLeg)]
            }
        } else {
            arrivalDwellCounter = 0
        }
        return []
    }

    private func checkParkingArrival(_ fix: LatLon) -> [NavigationEffect] {
        guard let parking = target?.parking, !parkingReached else { return [] }
        let d = haversineMeters(fix, parking)
        if d < NavConstants.parkingRadius {
            parkingReached = true
            snapshot.navState = .calculating
            mode = .walking
            offRouteCounter = 0
            pendingDirectionsFetch = false
            return [.reachedParking(notes: nil),
                    .announce("Sie haben den Parkplatz erreicht. Weiter zu Fuß."),
                    .needsDirections(destination: target?.destination ?? parking, mode: .walking,
                                     reason: .parkingToCustomerWalk)]
        }
        return []
    }

    private func firstAnnouncedInstruction() -> String {
        guard !steps.isEmpty else { return "" }
        let nextIdx = min(snapshot.currentStepIndex + 1, steps.count - 1)
        return steps[nextIdx].instruction
    }

    private func refreshInstructions(fix: LatLon? = nil) {
        guard !steps.isEmpty else { return }
        let idx = min(snapshot.currentStepIndex, steps.count - 1)
        let nextIdx = min(idx + 1, steps.count - 1)
        snapshot.currentInstruction = steps[idx].instruction
        snapshot.nextInstruction = steps[nextIdx].instruction
        snapshot.maneuver = steps[nextIdx].maneuver
        snapshot.travelMode = steps[idx].travelMode
    }

    private func updateBearing(_ fix: LocationFix) {
        let threshold = mode == .walking ? 0.5 : 2.0
        if let b = fix.bearing, fix.speed > threshold {
            snapshot.bearing = b
        } else if steps.indices.contains(snapshot.currentStepIndex) {
            snapshot.bearing = headingDegrees(from: fix.coord, to: steps[snapshot.currentStepIndex].endLocation)
        }
    }
}
