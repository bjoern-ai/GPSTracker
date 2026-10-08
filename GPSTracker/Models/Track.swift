import Foundation
import CoreLocation

struct Track: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var points: [TrackPoint]
    var startDate: Date
    var endDate: Date?

    init(id: UUID = UUID(), name: String, points: [TrackPoint] = [], startDate: Date = Date(), endDate: Date? = nil) {
        self.id = id
        self.name = name
        self.points = points
        self.startDate = startDate
        self.endDate = endDate
    }

    var duration: TimeInterval {
        guard let endDate else { return Date().timeIntervalSince(startDate) }
        return endDate.timeIntervalSince(startDate)
    }

    var distance: Double {
        guard points.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<points.count {
            total += points[i].clLocation.distance(from: points[i - 1].clLocation)
        }
        return total
    }

    var maxAltitude: Double { points.map(\.altitude).max() ?? 0 }
    var minAltitude: Double { points.map(\.altitude).min() ?? 0 }

    var elevationGain: Double {
        guard points.count > 1 else { return 0 }
        var gain: Double = 0
        for i in 1..<points.count {
            let diff = points[i].altitude - points[i - 1].altitude
            if diff > 0 { gain += diff }
        }
        return gain
    }

    var averageSpeed: Double {
        let d = duration
        guard d > 0 else { return 0 }
        return distance / d
    }

    var maxSpeed: Double {
        points.map { max($0.speed, 0) }.max() ?? 0
    }
}
