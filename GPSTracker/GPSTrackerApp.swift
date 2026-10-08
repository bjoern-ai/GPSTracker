import SwiftUI

@main
struct GPSTrackerApp: App {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var trackStore = TrackStore.shared
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
