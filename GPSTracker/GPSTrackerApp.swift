import SwiftUI

@main
struct GPSTrackerApp: App {
    // Plain references: observing them here would rebuild the whole UI on every
    // location update, which made text input stutter. Views observe them instead.
    private let locationManager = LocationManager.shared
    private let trackStore = TrackStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(trackStore)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                trackStore.sync()
            }
        }
    }
}
