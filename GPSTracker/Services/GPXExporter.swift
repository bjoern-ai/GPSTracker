import Foundation

/// Builds GPX 1.1 XML for a track and writes it to a temporary file for sharing.
struct GPXExporter {
    static func gpxString(for track: Track) -> String {
        let isoFormatter = ISO8601DateFormatter()
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GPSTracker" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escape(track.name))</name>
            <time>\(isoFormatter.string(from: track.startDate))</time>
          </metadata>
          <trk>
            <name>\(escape(track.name))</name>
            <trkseg>

        """
        for point in track.points {
            xml += """
                  <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                    <ele>\(point.altitude)</ele>
                    <time>\(isoFormatter.string(from: point.timestamp))</time>
                  </trkpt>

            """
        }
        xml += """
            </trkseg>
          </trk>
        </gpx>
        """
        return xml
    }

    static func exportToFile(track: Track) -> URL? {
        let gpx = gpxString(for: track)
        let fileName = sanitizedFileName(track.name) + ".gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try gpx.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func sanitizedFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = name.components(separatedBy: allowed.inverted).joined()
        return cleaned.isEmpty ? "Strecke" : cleaned
    }
}
