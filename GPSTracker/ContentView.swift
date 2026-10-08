import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LiveTrackingView()
                .tabItem { Label("Live", systemImage: "location.fill") }
            SavedTracksView()
                .tabItem { Label("Strecken", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager.shared)
        .environmentObject(TrackStore.shared)
}
