import SwiftUI
import UniformTypeIdentifiers

struct SavedTracksView: View {
    /// One file importer serves both pickers; two on the same view would conflict.
    private enum FilePicker {
        case syncFolder, gpx

        var contentTypes: [UTType] {
            switch self {
            case .syncFolder: return [.folder]
            case .gpx: return UTType.gpxFileTypes
            }
        }
    }

    @EnvironmentObject var trackStore: TrackStore
    @State private var filePicker = FilePicker.gpx
    @State private var showFilePicker = false
    @State private var path: [Track] = []
    @State private var importError: String?

    var body: some View {
        NavigationStack(path: $path) {
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
                        description: Text("Aufgezeichnete und importierte Strecken erscheinen hier.")
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        presentFilePicker(.gpx)
                    } label: {
                        Label("GPX importieren", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    syncMenu
                }
            }
            .navigationDestination(for: Track.self) { track in
                TrackDetailView(track: track)
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: filePicker.contentTypes) { result in
                guard case .success(let url) = result else { return }
                switch filePicker {
                case .syncFolder: trackStore.setSyncFolder(url)
                case .gpx: importGPX(from: url)
                }
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
    }

    private func presentFilePicker(_ picker: FilePicker) {
        filePicker = picker
        showFilePicker = true
    }

    private func importGPX(from url: URL) {
        Task {
            do {
                let track = try await trackStore.importGPX(from: url)
                path = [track]
            } catch {
                importError = error.localizedDescription
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
                        presentFilePicker(.syncFolder)
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
                        presentFilePicker(.syncFolder)
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
