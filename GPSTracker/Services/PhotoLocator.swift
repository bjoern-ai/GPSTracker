import Foundation
import CoreLocation
import ImageIO
import UIKit

/// A selected photo placed on the track map.
struct PhotoPin: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let date: Date?
    /// True if the position was derived from the photo's time instead of its GPS data.
    let isEstimated: Bool
    let thumbnail: UIImage
    /// The original file; the large preview is decoded from it only when shown.
    let data: Data
}

/// Reads location and capture time from photo metadata (EXIF/GPS).
enum PhotoLocator {
    /// Places a photo by its GPS data, or else by its capture time along the
    /// track. Returns nil if neither works.
    static func pin(id: Int, data: Data, track: Track) -> PhotoPin? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let thumbnail = image(from: source, maxPixelSize: 160) else { return nil }

        let date = captureDate(from: properties)
        let coordinate: CLLocationCoordinate2D
        let isEstimated: Bool
        if let gps = gpsCoordinate(from: properties) {
            coordinate = gps
            isEstimated = false
        } else if let date, let interpolated = interpolatedCoordinate(at: date, in: track.points) {
            coordinate = interpolated
            isEstimated = true
        } else {
            return nil
        }
        return PhotoPin(id: id, coordinate: coordinate, date: date, isEstimated: isEstimated,
                        thumbnail: UIImage(cgImage: thumbnail), data: data)
    }

    static func previewImage(from data: Data, maxPixelSize: Int = 2048) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = image(from: source, maxPixelSize: maxPixelSize) else { return nil }
        return UIImage(cgImage: image)
    }

    private static func image(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func gpsCoordinate(from properties: [CFString: Any]) -> CLLocationCoordinate2D? {
        guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              var latitude = (gps[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue,
              var longitude = (gps[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue else { return nil }
        if (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased() == "S" { latitude = -latitude }
        if (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased() == "W" { longitude = -longitude }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    /// EXIF stores the local time, e.g. "2026:10:08 14:05:31", with the UTC
    /// offset in a separate field. Without one the device's time zone is assumed.
    private static func captureDate(from properties: [CFString: Any]) -> Date? {
        guard let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let string = (exif[kCGImagePropertyExifDateTimeOriginal] ?? exif[kCGImagePropertyExifDateTimeDigitized]) as? String
        else { return nil }
        let offset = (exif[kCGImagePropertyExifOffsetTimeOriginal] ?? exif[kCGImagePropertyExifOffsetTime]) as? String

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = offset.flatMap(timeZone(fromOffset:)) ?? .current
        return formatter.date(from: string)
    }

    /// Parses offsets like "+02:00" or "-05:30".
    private static func timeZone(fromOffset offset: String) -> TimeZone? {
        let parts = offset.dropFirst().split(separator: ":").compactMap { Int($0) }
        guard let sign = offset.first, sign == "+" || sign == "-", parts.count == 2 else { return nil }
        let seconds = (parts[0] * 3600 + parts[1] * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }

    /// Position on the track at `date`, interpolated between the surrounding
    /// points. Nil if the date lies outside the recorded time range.
    static func interpolatedCoordinate(at date: Date, in points: [TrackPoint]) -> CLLocationCoordinate2D? {
        guard let first = points.first, let last = points.last,
              first.timestamp <= date, date <= last.timestamp else { return nil }
        var low = 0
        var high = points.count - 1
        while low < high {
            let mid = (low + high) / 2
            if points[mid].timestamp < date { low = mid + 1 } else { high = mid }
        }
        let after = points[low]
        guard low > 0 else { return after.coordinate }
        let before = points[low - 1]
        let span = after.timestamp.timeIntervalSince(before.timestamp)
        let fraction = span > 0 ? date.timeIntervalSince(before.timestamp) / span : 0
        return CLLocationCoordinate2D(
            latitude: before.latitude + (after.latitude - before.latitude) * fraction,
            longitude: before.longitude + (after.longitude - before.longitude) * fraction
        )
    }
}
