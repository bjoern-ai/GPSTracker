import AppIntents

/// Shortcuts actions to start, stop and toggle a recording. Starting opens the
/// app, because iOS only lets an app begin location updates in the foreground.
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Aufzeichnung starten"
    static let description = IntentDescription("Startet eine neue GPS-Aufzeichnung.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let locationManager = LocationManager.shared
        guard !locationManager.isRecording else {
            return .result(dialog: "Es läuft bereits eine Aufzeichnung.")
        }
        locationManager.startRecording(name: Track.defaultName())
        return .result(dialog: "Aufzeichnung gestartet.")
    }
}

struct StopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Aufzeichnung beenden"
    static let description = IntentDescription("Beendet die laufende Aufzeichnung und speichert die Strecke.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: RecordingControl.stop()))
    }
}

/// One action for both directions, e.g. for the Action Button. It always opens
/// the app so that starting works without an extra confirmation.
struct ToggleRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Aufzeichnung umschalten"
    static let description = IntentDescription("Startet eine Aufzeichnung oder beendet und speichert die laufende.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let locationManager = LocationManager.shared
        if locationManager.isRecording {
            return .result(dialog: IntentDialog(stringLiteral: RecordingControl.stop()))
        }
        locationManager.startRecording(name: Track.defaultName())
        return .result(dialog: "Aufzeichnung gestartet.")
    }
}

@MainActor
enum RecordingControl {
    /// Stops the recording and saves the track. Returns the text to show or speak.
    static func stop() -> String {
        let locationManager = LocationManager.shared
        guard locationManager.isRecording else {
            return "Es läuft gerade keine Aufzeichnung."
        }
        let track = locationManager.stopRecording()
        guard !track.points.isEmpty else {
            return "Aufzeichnung beendet. Es wurden keine Punkte aufgezeichnet, daher wurde nichts gespeichert."
        }
        TrackStore.shared.save(track)
        let km = (track.distance / 1000).formatted(.number.precision(.fractionLength(2)))
        return "Strecke „\(track.name)“ mit \(km) km gespeichert."
    }
}

struct GPSTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Starte Aufzeichnung in \(.applicationName)",
                "Starte \(.applicationName) Aufzeichnung",
                "Neue Strecke mit \(.applicationName) aufzeichnen"
            ],
            shortTitle: "Aufzeichnung starten",
            systemImageName: "record.circle"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Beende Aufzeichnung in \(.applicationName)",
                "Stoppe \(.applicationName) Aufzeichnung"
            ],
            shortTitle: "Aufzeichnung beenden",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: ToggleRecordingIntent(),
            phrases: [
                "Schalte Aufzeichnung in \(.applicationName) um"
            ],
            shortTitle: "Aufzeichnung umschalten",
            systemImageName: "playpause.circle"
        )
    }
}
