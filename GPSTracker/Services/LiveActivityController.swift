import ActivityKit
import Foundation

/// Mirrors the running recording in a Live Activity on the lock screen and in
/// the Dynamic Island. Updates are throttled, because iOS limits how often an
/// activity may change; the elapsed time ticks on its own as a timer text.
final class LiveActivityController {
    static let shared = LiveActivityController()

    private typealias State = RecordingActivityAttributes.ContentState

    private var activity: Activity<RecordingActivityAttributes>?
    private var lastUpdate = Date.distantPast
    private var lastState: State?
    private let minimumInterval: TimeInterval = 5

    func start(track: Track) {
        endStaleActivities()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RecordingActivityAttributes(trackName: track.name, startDate: track.startDate)
        let state = State(elapsed: 0, distance: 0, speed: 0, isPaused: false)
        do {
            activity = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
            lastState = state
            lastUpdate = Date()
        } catch {
            print("Live Activity could not be started: \(error.localizedDescription)")
        }
    }

    /// Sends the current values, at most every few seconds unless the pause
    /// state changed or `force` is set.
    func update(track: Track, speed: Double, isPaused: Bool, force: Bool = false) {
        guard let activity else { return }
        let now = Date()
        let pauseChanged = lastState?.isPaused != isPaused
        guard force || pauseChanged || now.timeIntervalSince(lastUpdate) >= minimumInterval else { return }

        let state = State(elapsed: track.duration, distance: track.distance, speed: isPaused ? 0 : speed, isPaused: isPaused)
        guard state != lastState else { return }
        lastState = state
        lastUpdate = now
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// Ends the activity and leaves a summary of the finished track on the lock screen for a while.
    func end(track: Track) {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        let state = State(elapsed: track.duration, distance: track.distance, speed: 0, isPaused: false, isFinished: true)
        Task {
            await activity.end(ActivityContent(state: state, staleDate: nil),
                               dismissalPolicy: .after(Date().addingTimeInterval(15 * 60)))
        }
    }

    /// Ends activities this controller doesn't know about, e.g. left over after
    /// the app was terminated during a recording.
    func endStaleActivities() {
        for stale in Activity<RecordingActivityAttributes>.activities where stale.id != activity?.id {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
