import SwiftUI
import UniformTypeIdentifiers

struct SavedTracksView: View {
    @EnvironmentObject var trackStore: TrackStore
    @State private var showFolderPicker = false

    var body: some View {
        NavigationStack {
            List {
                if let error = trackStore.syncError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if trackStore.tracks.isEmpty {
                    ContentUnavailableView(
                        "Keine Strecken",
                        systemImage: "map",
                        description: Text("Aufgezeichnete Strecken erscheinen hier.")
                    )
                }
                ForEach(trackStore.tracks) { track in
                    NavigationLink(value: track) {
                        TrackRow(track: track)
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { trackStore.tracks[$0] }.forEach(trackStore.delete)
                }
            }
            .refreshable {
                trackStore.loadTracks()
                trackStore.sync()
            }
            .navigationTitle("Strecken")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    syncMenu
                }
            }
            .navigationDestination(for: Track.self) { track in
                TrackDetailView(track: track)
            }
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    trackStore.setSyncFolder(url)
                }
            }
        }
    }

    private var syncMenu: some View {
        Menu {
            if let folderName = trackStore.syncFolderName {
                Section(syncStatusText(folderName: folderName)) {
                    Button {
                        trackStore.sync()
                    } label: {
                        Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label("Anderen Ordner wählen …", systemImage: "folder")
                    }
                    Button(role: .destructive) {
                        trackStore.removeSyncFolder()
                    } label: {
                        Label("Sync beenden", systemImage: "xmark.icloud")
                    }
                }
            } else {
                Section("Strecken werden nur auf diesem Gerät gespeichert.") {
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label("Sync-Ordner wählen …", systemImage: "folder.badge.plus")
                    }
                }
            }
        } label: {
            if trackStore.isSyncing {
                ProgressView()
            } else if trackStore.syncError != nil {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: trackStore.syncFolderName != nil ? "icloud.fill" : "icloud.slash")
            }
        }
        .accessibilityLabel("Synchronisierung")
    }

    private func syncStatusText(folderName: String) -> String {
        guard let date = trackStore.lastSyncDate else { return "Ordner: \(folderName)" }
        return "Ordner: \(folderName) · zuletzt \(date.formatted(date: .omitted, time: .shortened))"
    }
}

struct TrackRow: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.name).font(.headline)
            HStack(spacing: 12) {
                Label(String(format: "%.2f km", track.distance / 1000), systemImage: "ruler")
                Label(durationText, systemImage: "clock")
                Label(String(format: "%.0f m", track.elevationGain), systemImage: "arrow.up.right")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var durationText: String {
        let duration = Int(track.duration)
        let h = duration / 3600
        let m = (duration % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }
}
