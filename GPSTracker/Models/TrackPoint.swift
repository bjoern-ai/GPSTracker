import Foundation
import CoreLocation

struct TrackPoint: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let course: Double

    init(location: CLLocation) {
        self.id = UUID()
        self.timestamp = location.timestamp
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.speed = location.speed
        self.course = location.course
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
