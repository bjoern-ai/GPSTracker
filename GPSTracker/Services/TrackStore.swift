import Foundation

/// Stores tracks as JSON files in the app's Documents folder and optionally
/// syncs them two-way with a folder the user picked (e.g. in iCloud Drive).
final class TrackStore: ObservableObject {
    static let shared = TrackStore()

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var syncFolderName: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?

    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard
    private let ioQueue = DispatchQueue(label: "TrackStore.io", qos: .userInitiated)
    private let bookmarkKey = "syncFolderBookmark"
    private let syncedIDsKey = "syncedTrackIDs"
    private let noAccessMessage = "Kein Zugriff auf den Sync-Ordner. Bitte wähle ihn erneut aus."

    private let localDirectory: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tracks", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private struct SyncFolder {
        let tracks: URL
        let gpx: URL
    }

    init() {
        loadTracks()
        syncFolderName = resolveSyncFolder()?.lastPathComponent
        sync()
    }

    // MARK: - Tracks

    func loadTracks() {
        let files = (try? fileManager.contentsOfDirectory(at: localDirectory, includingPropertiesForKeys: nil)) ?? []
        tracks = files
            .filter { $0.pathExtension == "json" }
            .compactMap { (try? Data(contentsOf: $0)).flatMap(Self.decode) }
            .sorted { $0.startDate > $1.startDate }
    }

    func save(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
        tracks.append(track)
        tracks.sort { $0.startDate > $1.startDate }

        ioQueue.async {
            guard let data = Self.encode(track) else { return }
            try? data.write(to: self.localURL(for: track.id), options: .atomic)
            self.withSyncFolder { folder in
                try self.upload(track, data: data, to: folder)
                self.syncedIDs.insert(track.id)
            }
        }
    }

    func delete(_ track: Track) {
        tracks.removeAll { $0.id == track.id }

        ioQueue.async {
            try? self.fileManager.removeItem(at: self.localURL(for: track.id))
            self.withSyncFolder { folder in
                try self.coordinatedDelete(folder.tracks.appendingPathComponent("\(track.id.uuidString).json"))
                try self.coordinatedDelete(folder.gpx.appendingPathComponent(self.gpxFileName(for: track)))
            }
            self.syncedIDs.remove(track.id)
        }
    }

    // MARK: - Sync folder

    func setSyncFolder(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? url.bookmarkData() else {
            syncError = noAccessMessage
            return
        }
        ioQueue.async {
            self.defaults.set(bookmark, forKey: self.bookmarkKey)
            self.defaults.removeObject(forKey: self.syncedIDsKey)
        }
        syncFolderName = url.lastPathComponent
        syncError = nil
        sync()
    }

    func removeSyncFolder() {
        ioQueue.async {
            self.defaults.removeObject(forKey: self.bookmarkKey)
            self.defaults.removeObject(forKey: self.syncedIDsKey)
        }
        syncFolderName = nil
        lastSyncDate = nil
        syncError = nil
    }

    func sync() {
        guard syncFolderName != nil, !isSyncing else { return }
        isSyncing = true
        ioQueue.async {
            let success = self.withSyncFolder { folder in
                try self.performSync(with: folder)
            }
            DispatchQueue.main.async {
                self.isSyncing = false
                if success { self.lastSyncDate = Date() }
                self.loadTracks()
            }
        }
    }

    /// Two-way merge. A track that was synced before but is now missing from
    /// the folder was deleted on another device, so it is removed locally too.
    private func performSync(with folder: SyncFolder) throws {
        let localIDs = Set(localTrackIDs())
        let remoteFiles = try remoteTrackFiles(in: folder.tracks)
        let remoteIDs = Set(remoteFiles.keys)
        var synced = syncedIDs

        for id in localIDs.subtracting(remoteIDs) {
            if synced.contains(id) {
                try? fileManager.removeItem(at: localURL(for: id))
                synced.remove(id)
            } else if let data = try? Data(contentsOf: localURL(for: id)), let track = Self.decode(data) {
                try upload(track, data: data, to: folder)
                synced.insert(id)
            }
        }

        for (id, url) in remoteFiles where !localIDs.contains(id) {
            // Skipped files (e.g. still downloading while offline) are retried on the next sync.
            guard let data = try? coordinatedRead(url), Self.decode(data) != nil else { continue }
            try data.write(to: localURL(for: id), options: .atomic)
            synced.insert(id)
        }

        synced.formUnion(localIDs.intersection(remoteIDs))
        syncedIDs = synced
    }

    /// Runs `work` with access to the sync folder. Returns false and reports the
    /// problem if no folder is set, access fails or `work` throws.
    @discardableResult
    private func withSyncFolder(_ work: (SyncFolder) throws -> Void) -> Bool {
        guard defaults.data(forKey: bookmarkKey) != nil else { return false }
        guard let root = resolveSyncFolder() else {
            report(noAccessMessage)
            return false
        }
        // Returns false for URLs that need no scoped access; real access problems surface as errors below.
        let accessing = root.startAccessingSecurityScopedResource()
        defer { if accessing { root.stopAccessingSecurityScopedResource() } }

        let folder = SyncFolder(
            tracks: root.appendingPathComponent("Tracks", isDirectory: true),
            gpx: root.appendingPathComponent("GPX", isDirectory: true)
        )
        do {
            try fileManager.createDirectory(at: folder.tracks, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: folder.gpx, withIntermediateDirectories: true)
            try work(folder)
            report(nil)
            return true
        } catch {
            report("Synchronisierung fehlgeschlagen: \(error.localizedDescription)")
            return false
        }
    }

    private func resolveSyncFolder() -> URL? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else { return nil }
        if isStale, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let fresh = try? url.bookmarkData() {
                defaults.set(fresh, forKey: bookmarkKey)
            }
        }
        return url
    }

    private func upload(_ track: Track, data: Data, to folder: SyncFolder) throws {
        try coordinatedWrite(data, to: folder.tracks.appendingPathComponent("\(track.id.uuidString).json"))
        try coordinatedWrite(Data(GPXExporter.gpxString(for: track).utf8),
                             to: folder.gpx.appendingPathComponent(gpxFileName(for: track)))
    }

    /// Maps track IDs to their JSON files in the folder, including iCloud
    /// placeholders (`.<name>.icloud`) for files that aren't downloaded yet.
    private func remoteTrackFiles(in directory: URL) throws -> [UUID: URL] {
        var coordinationError: NSError?
        var listing: Result<[URL], Error> = .success([])
        NSFileCoordinator().coordinate(readingItemAt: directory, options: [], error: &coordinationError) { url in
            listing = Result { try self.fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) }
        }
        if let coordinationError { throw coordinationError }

        var files: [UUID: URL] = [:]
        for url in try listing.get() {
            var name = url.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                name = String(name.dropFirst().dropLast(".icloud".count))
            }
            guard name.hasSuffix(".json"), let id = UUID(uuidString: String(name.dropLast(".json".count))) else { continue }
            files[id] = directory.appendingPathComponent(name)
        }
        return files
    }

    // MARK: - Helpers

    private var syncedIDs: Set<UUID> {
        get { Set((defaults.stringArray(forKey: syncedIDsKey) ?? []).compactMap(UUID.init(uuidString:))) }
        set { defaults.set(newValue.map(\.uuidString), forKey: syncedIDsKey) }
    }

    private func localURL(for id: UUID) -> URL {
        localDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func localTrackIDs() -> [UUID] {
        let files = (try? fileManager.contentsOfDirectory(at: localDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { url in
            url.pathExtension == "json" ? UUID(uuidString: url.deletingPathExtension().lastPathComponent) : nil
        }
    }

    private func gpxFileName(for track: Track) -> String {
        "\(GPXExporter.sanitizedFileName(track.name))_\(track.id.uuidString.prefix(4)).gpx"
    }

    private func report(_ message: String?) {
        DispatchQueue.main.async { self.syncError = message }
    }

    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }

    private func coordinatedRead(_ url: URL) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            result = Result { try Data(contentsOf: url) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    private func coordinatedDelete(_ url: URL) throws {
        var coordinationError: NSError?
        var deleteError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { url in
            do {
                try FileManager.default.removeItem(at: url)
            } catch CocoaError.fileNoSuchFile {
                // Already gone, nothing to do.
            } catch {
                deleteError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let deleteError { throw deleteError }
    }

    private static func encode(_ track: Track) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(track)
    }

    private static func decode(_ data: Data) -> Track? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Track.self, from: data)
    }
}
