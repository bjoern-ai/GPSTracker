import SwiftUI
import MapKit

/// Shows a route as a polyline. In live mode it follows the device's
/// location; for a saved track it fits the camera to the route's bounds.
struct TrackMapView: View {
    let points: [TrackPoint]
    var isLive: Bool = true

    @State private var cameraPosition: MapCameraPosition

    init(points: [TrackPoint], isLive: Bool = true) {
        self.points = points
        self.isLive = isLive
        _cameraPosition = State(initialValue: isLive ? .userLocation(fallback: .automatic) : .automatic)
    }

    var body: some View {
        Map(position: $cameraPosition) {
            if points.count > 1 {
                MapPolyline(coordinates: points.map(\.coordinate))
                    .stroke(.blue, lineWidth: 4)
            }
            if isLive {
                UserAnnotation()
            } else {
                if let first = points.first {
                    Annotation("Start", coordinate: first.coordinate) {
                        startEndMarker(systemImage: "flag.circle.fill", color: .green)
                    }
                }
                if let last = points.last, points.count > 1 {
                    Annotation("Ende", coordinate: last.coordinate) {
                        startEndMarker(systemImage: "flag.checkered.circle.fill", color: .red)
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            if !isLive, points.count > 1 {
                fitToRoute()
            }
        }
    }

    private func startEndMarker(systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(color)
            .background(Circle().fill(.white))
    }

    private func fitToRoute() {
        let coords = points.map(\.coordinate)
        guard let firstLat = coords.first?.latitude, let firstLon = coords.first?.longitude else { return }
        var minLat = firstLat, maxLat = firstLat
        var minLon = firstLon, maxLon = firstLon
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.01)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}
