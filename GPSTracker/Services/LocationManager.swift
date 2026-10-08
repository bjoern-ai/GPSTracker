import Foundation
import CoreLocation
import Combine

/// Wraps CLLocationManager, publishes live values for the UI and
/// accumulates points into `currentTrack` while recording.
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()

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
    }

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
    }

    func pauseRecording() {
        isPaused = true
    }

    func resumeRecording() {
        isPaused = false
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
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }
}
