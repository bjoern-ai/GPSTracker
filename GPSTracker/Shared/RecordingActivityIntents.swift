import AppIntents

// Buttons of the recording Live Activity. The widget extension needs the types
// to show the buttons, but iOS runs `perform()` in the app, so only the app's
// copy touches the recording.

struct PauseResumeRecordingActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Aufzeichnung pausieren oder fortsetzen"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let locationManager = LocationManager.shared
        if locationManager.isRecording {
            locationManager.isPaused ? locationManager.resumeRecording() : locationManager.pauseRecording()
        }
        #endif
        return .result()
    }
}

struct StopRecordingActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Aufzeichnung beenden"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        _ = RecordingControl.stop()
        #endif
        return .result()
    }
}
