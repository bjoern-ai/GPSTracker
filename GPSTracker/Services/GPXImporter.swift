import Foundation
import CoreLocation
import UniformTypeIdentifiers

extension UTType {
    static let gpx = UTType(importedAs: "com.topografix.gpx", conformingTo: .xml)
}

/// Reads GPX files into tracks. Uses the points of all track segments, or the
/// route points if the file has no track. Elevation and time are optional.
enum GPXImporter {
    enum ImportError: LocalizedError {
        case unreadable
        case invalidFile
        case noPoints

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "Die Datei konnte nicht gelesen werden."
            case .invalidFile:
                return "Die Datei ist keine gültige GPX-Datei."
            case .noPoints:
                return "Die GPX-Datei enthält keine Strecken- oder Routenpunkte."
            }
        }
    }

    /// Reads the file at `url`, which may be outside the app's sandbox.
    static func track(from url: URL) throws -> Track {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        return try track(from: data, fallbackName: url.deletingPathExtension().lastPathComponent)
    }

    static func track(from data: Data, fallbackName: String) throws -> Track {
        let parser = XMLParser(data: data)
        let handler = ParserHandler()
        parser.delegate = handler
        parser.shouldProcessNamespaces = true
        guard parser.parse(), handler.sawGPXRoot else { throw ImportError.invalidFile }

        let rawPoints = handler.trackPoints.isEmpty ? handler.routePoints : handler.trackPoints
        guard !rawPoints.isEmpty else { throw ImportError.noPoints }

        let name = [handler.trackName, handler.routeName, handler.metadataName, fallbackName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? Track.defaultName()

        // Files without times get the import time, so duration and speeds are zero.
        let fallbackDate = handler.metadataTime ?? Date()
        // Points without elevation take the nearest known one, so the profile has no drops to zero.
        var lastElevation = rawPoints.lazy.compactMap(\.elevation).first
        var points: [TrackPoint] = []
        points.reserveCapacity(rawPoints.count)
        for (index, raw) in rawPoints.enumerated() {
            let timestamp = raw.time ?? fallbackDate
            if let elevation = raw.elevation { lastElevation = elevation }
            var speed = -1.0
            if index > 0, let time = raw.time, let previousTime = rawPoints[index - 1].time {
                let interval = time.timeIntervalSince(previousTime)
                if interval > 0 {
                    let previous = CLLocation(latitude: rawPoints[index - 1].latitude, longitude: rawPoints[index - 1].longitude)
                    speed = CLLocation(latitude: raw.latitude, longitude: raw.longitude).distance(from: previous) / interval
                }
            }
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: raw.latitude, longitude: raw.longitude),
                altitude: lastElevation ?? 0,
                horizontalAccuracy: 0,
                verticalAccuracy: raw.elevation == nil ? -1 : 0,
                course: -1,
                speed: speed,
                timestamp: timestamp
            )
            points.append(TrackPoint(location: location))
        }

        let startDate = points.first?.timestamp ?? fallbackDate
        let endDate = max(points.last?.timestamp ?? startDate, startDate)
        return Track(name: name, points: points, startDate: startDate, endDate: endDate)
    }

    private struct RawPoint {
        let latitude: Double
        let longitude: Double
        var elevation: Double?
        var time: Date?
    }

    private final class ParserHandler: NSObject, XMLParserDelegate {
        var sawGPXRoot = false
        var trackPoints: [RawPoint] = []
        var routePoints: [RawPoint] = []
        var trackName: String?
        var routeName: String?
        var metadataName: String?
        var metadataTime: Date?

        private var path: [String] = []
        private var currentPoint: RawPoint?
        private var text = ""

        private let dateFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()
        private let fractionalDateFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            if path.isEmpty, elementName == "gpx" { sawGPXRoot = true }
            path.append(elementName)
            text = ""
            if elementName == "trkpt" || elementName == "rtept",
               let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init),
               (-90...90).contains(lat), (-180...180).contains(lon) {
                currentPoint = RawPoint(latitude: lat, longitude: lon)
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            path.removeLast()
            let parent = path.last

            switch (elementName, parent) {
            case ("ele", "trkpt"), ("ele", "rtept"):
                currentPoint?.elevation = Double(value)
            case ("time", "trkpt"), ("time", "rtept"):
                currentPoint?.time = date(from: value)
            case ("trkpt", _):
                if let point = currentPoint { trackPoints.append(point) }
                currentPoint = nil
            case ("rtept", _):
                if let point = currentPoint { routePoints.append(point) }
                currentPoint = nil
            case ("name", "trk"):
                if trackName == nil { trackName = value }
            case ("name", "rte"):
                if routeName == nil { routeName = value }
            case ("name", "metadata"):
                metadataName = value
            case ("time", "metadata"):
                metadataTime = date(from: value)
            default:
                break
            }
            text = ""
        }

        private func date(from string: String) -> Date? {
            dateFormatter.date(from: string) ?? fractionalDateFormatter.date(from: string)
        }
    }
}
