import SwiftUI

/// Full-screen turn-by-turn navigation (named TurnByTurnView to avoid shadowing
/// SwiftUI's deprecated NavigationView). Pushed onto the nav stack (NOT a modal
/// cover) and given an explicit frame — GMSMapView (Metal) renders black in a
/// modal / at zero size.
struct TurnByTurnView: View {
    @StateObject private var vm: NavigationViewModel
    @Environment(\.dismiss) private var dismiss

    init(api: APIClient, routeId: String?, target: NavTarget) {
        _vm = StateObject(wrappedValue: NavigationViewModel(api: api, routeId: routeId, target: target))
    }

    var body: some View {
        GeometryReader { geo in
            NavMapView(location: vm.location,
                       bearing: vm.bearing,
                       walking: vm.snapshot.travelMode == .walking,
                       routePolyline: vm.routePolyline)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { instructionBanner }
        .overlay(alignment: .bottom) { bottomBar }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.start() }
        .onDisappear { vm.stop() }
    }

    private var instructionBanner: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: maneuverIcon(vm.snapshot.maneuver)).font(.title2)
                Text(vm.snapshot.nextInstruction ?? statusText)
                    .font(.headline).multilineTextAlignment(.leading)
                Spacer()
            }
            if vm.snapshot.distanceToNextManeuver > 0 {
                HStack {
                    Text("in \(vm.snapshot.distanceToNextManeuver) m")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
            }
            if vm.snapshot.isOffRoute {
                HStack { Text("Route wird neu berechnet…").font(.caption).foregroundStyle(.orange); Spacer() }
            }
            if let err = vm.errorMessage {
                HStack { Text(err).font(.caption).foregroundStyle(.red); Spacer() }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding()
    }

    private var bottomBar: some View {
        HStack {
            if vm.snapshot.distanceToDestination > 0 {
                Label("\(vm.snapshot.distanceToDestination) m", systemImage: "flag.checkered")
                    .font(.subheadline)
            }
            Spacer()
            Button(role: .destructive) {
                vm.stop()
                dismiss()
            } label: {
                Text("Beenden")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding()
    }

    private var statusText: String {
        switch vm.snapshot.navState {
        case .calculating, .rerouting: return "Route wird berechnet…"
        case .arrived: return "Sie sind angekommen"
        case .idle: return "Navigation startet…"
        default: return "Weiterfahren"
        }
    }

    private func maneuverIcon(_ m: Maneuver?) -> String {
        switch m {
        case .turnLeft, .turnSlightLeft, .turnSharpLeft, .forkLeft, .rampLeft, .keepLeft, .roundaboutLeft:
            return "arrow.turn.up.left"
        case .turnRight, .turnSlightRight, .turnSharpRight, .forkRight, .rampRight, .keepRight, .roundaboutRight:
            return "arrow.turn.up.right"
        case .turnU: return "arrow.uturn.down"
        case .arrive: return "flag.checkered"
        case .merge: return "arrow.merge"
        default: return "arrow.up"
        }
    }
}
