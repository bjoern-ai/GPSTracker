import SwiftUI
import MapKit

/// Shows a route as a polyline. In live mode it follows the device's
/// location; for a saved track it fits the camera to the route's bounds and
/// can show photos as thumbnails.
struct TrackMapView: View {
    let points: [TrackPoint]
    var isLive: Bool = true
    var photoPins: [PhotoPin] = []
    var onSelectPhoto: ((PhotoPin) -> Void)?

    @State private var cameraPosition: MapCameraPosition

    init(points: [TrackPoint], isLive: Bool = true, photoPins: [PhotoPin] = [], onSelectPhoto: ((PhotoPin) -> Void)? = nil) {
        self.points = points
        self.isLive = isLive
        self.photoPins = photoPins
        self.onSelectPhoto = onSelectPhoto
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
                ForEach(photoPins) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .bottom) {
                        photoMarker(pin)
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

    private func photoMarker(_ pin: PhotoPin) -> some View {
        Button {
            onSelectPhoto?(pin)
        } label: {
            Image(uiImage: pin.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Foto")
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
