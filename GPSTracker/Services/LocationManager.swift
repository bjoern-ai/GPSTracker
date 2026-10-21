import Foundation
import CoreLocation
import Combine

/// Wraps CLLocationManager, publishes live values for the UI and
/// accumulates points into `currentTrack` while recording.
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let liveActivity = LiveActivityController.shared

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentLocation: CLLocation?
    @Published var currentSpeed: Double = 0
    @Published var currentAltitude: Double = 0
    @Published var currentCourse: Double = 0
    @Published var horizontalAccuracy: Double = -1

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentTrack = Track(name: "Neue Strecke")

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        #if DEBUG
        loadScreenshotDemoIfRequested()
        #endif
        // A recording doesn't survive the app being terminated, so neither should its Live Activity.
        liveActivity.endStaleActivities()
    }

    #if DEBUG
    private var isScreenshotDemo = false

    /// Screenshot helper: launching with `-ScreenshotDemoLive <file>` shows the
    /// track in Documents/<file> as a running recording and ignores real updates.
    private func loadScreenshotDemoIfRequested() {
        guard let file = UserDefaults.standard.string(forKey: "ScreenshotDemoLive") else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(file)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              var track = try? decoder.decode(Track.self, from: data),
              let first = track.points.first, let last = track.points.last else { return }
        track.startDate = Date().addingTimeInterval(-last.timestamp.timeIntervalSince(first.timestamp))
        track.endDate = nil
        currentTrack = track
        currentSpeed = last.speed
        currentAltitude = last.altitude
        horizontalAccuracy = last.horizontalAccuracy
        isRecording = true
        isScreenshotDemo = true
    }
    #endif

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        guard !isRecording else { return }
        manager.stopUpdatingLocation()
    }

    func startRecording(name: String) {
        currentTrack = Track(name: name)
        isRecording = true
        isPaused = false
        manager.allowsBackgroundLocationUpdates = authorizationStatus == .authorizedAlways
        manager.showsBackgroundLocationIndicator = true
        startUpdating()
        liveActivity.start(track: currentTrack)
    }

    func pauseRecording() {
        isPaused = true
        liveActivity.update(track: currentTrack, speed: currentSpeed, isPaused: true, force: true)
    }

    func resumeRecording() {
        isPaused = false
        liveActivity.update(track: currentTrack, speed: currentSpeed, isPaused: false, force: true)
    }

    /// Stops the recording, clears the live view and returns the finished
    /// track. The caller is responsible for persisting it via `TrackStore`.
    @discardableResult
    func stopRecording() -> Track {
        isRecording = false
        isPaused = false
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        var finished = currentTrack
        finished.endDate = Date()
        currentTrack = Track(name: "Neue Strecke")
        liveActivity.end(track: finished)
        return finished
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        #if DEBUG
        if isScreenshotDemo { return }
        #endif
        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentSpeed = max(location.speed, 0)
            self.currentAltitude = location.altitude
            self.currentCourse = location.course
            self.horizontalAccuracy = location.horizontalAccuracy

            if self.isRecording, !self.isPaused,
               location.horizontalAccuracy >= 0, location.horizontalAccuracy < 50 {
                self.currentTrack.points.append(TrackPoint(location: location))
            }
            if self.isRecording {
                self.liveActivity.update(track: self.currentTrack, speed: self.currentSpeed, isPaused: self.isPaused)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }
}
