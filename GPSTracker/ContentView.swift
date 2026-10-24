import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case live, tracks, settings
    }

    @EnvironmentObject var trackStore: TrackStore
    @State private var selectedTab = Tab.live
    @State private var importedTrackName: String?
    @State private var importError: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            LiveTrackingView()
                .tabItem { Label("Live", systemImage: "location.fill") }
                .tag(Tab.live)
            SavedTracksView()
                .tabItem { Label("Strecken", systemImage: "list.bullet") }
                .tag(Tab.tracks)
            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .onOpenURL { url in
            importGPX(from: url)
        }
        .alert("Strecke importiert", isPresented: Binding(
            get: { importedTrackName != nil },
            set: { if !$0 { importedTrackName = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("„\(importedTrackName ?? "")“ wurde zu deinen Strecken hinzugefügt.")
        }
        .alert("Import fehlgeschlagen", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    /// Handles GPX files opened from other apps, e.g. via "Teilen" or the Files app.
    private func importGPX(from url: URL) {
        guard url.isFileURL else { return }
        Task {
            do {
                let track = try await trackStore.importGPX(from: url)
                selectedTab = .tracks
                importedTrackName = track.name
            } catch {
                importError = error.localizedDescription
            }
            // iOS copies opened files into Documents/Inbox; the track is stored separately.
            if url.deletingLastPathComponent().lastPathComponent == "Inbox" {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager.shared)
        .environmentObject(TrackStore.shared)
}
