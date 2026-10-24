import ActivityKit
import Foundation

/// Data of the recording Live Activity. Compiled into the app and the widget extension.
struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Seconds since the start, used once the recording has finished.
        var elapsed: TimeInterval
        /// Meters.
        var distance: Double
        /// Meters per second.
        var speed: Double
        var isPaused: Bool
        var isFinished: Bool = false
    }

    var trackName: String
    var startDate: Date
}

/// German number formatting for the Live Activity, e.g. "3,42 km" and "12,5 km/h".
enum RecordingActivityFormat {
    private static let locale = Locale(identifier: "de_DE")

    static func distance(_ meters: Double) -> String {
        let km = (meters / 1000).formatted(.number.precision(.fractionLength(2)).locale(locale))
        return "\(km) km"
    }

    static func speed(_ metersPerSecond: Double) -> String {
        let kmh = (max(metersPerSecond, 0) * 3.6).formatted(.number.precision(.fractionLength(1)).locale(locale))
        return "\(kmh) km/h"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let duration = Int(seconds)
        return String(format: "%d:%02d:%02d", duration / 3600, (duration % 3600) / 60, duration % 60)
    }
}
