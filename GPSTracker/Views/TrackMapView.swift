import SwiftUI
import MapKit

/// Shows a route as a polyline. In live mode it follows the device's
/// location; for a saved track it fits the camera to the route's bounds and
/// can show photos as thumbnails. Photos that would overlap on screen are
/// grouped into one marker with a count.
struct TrackMapView: View {
    let points: [TrackPoint]
    var isLive: Bool = true
    var photoPins: [PhotoPin] = []
    var onSelectPhotos: (([PhotoPin]) -> Void)?

    @State private var cameraPosition: MapCameraPosition
    @State private var visibleLatitudeDelta: Double?

    private static let markerSize: CGFloat = 40

    private struct PhotoGroup: Identifiable {
        var pins: [PhotoPin]
        var id: Int { pins[0].id }
        var coordinate: CLLocationCoordinate2D { pins[0].coordinate }
    }

    init(points: [TrackPoint], isLive: Bool = true, photoPins: [PhotoPin] = [], onSelectPhotos: (([PhotoPin]) -> Void)? = nil) {
        self.points = points
        self.isLive = isLive
        self.photoPins = photoPins
        self.onSelectPhotos = onSelectPhotos
        _cameraPosition = State(initialValue: isLive ? .userLocation(fallback: .automatic) : .automatic)
    }

    var body: some View {
        GeometryReader { geometry in
            map(groups: photoGroups(mapHeight: geometry.size.height))
        }
    }

    private func map(groups: [PhotoGroup]) -> some View {
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
                ForEach(groups) { group in
                    Annotation("", coordinate: group.coordinate, anchor: .bottom) {
                        photoMarker(group)
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleLatitudeDelta = context.region.span.latitudeDelta
        }
        .onAppear {
            if !isLive, points.count > 1 {
                fitToRoute()
            }
        }
    }

    /// Greedily groups photos that lie within one marker size of a group's
    /// first photo at the current zoom. Before the map reports its region,
    /// photos within about 25 m are grouped.
    private func photoGroups(mapHeight: CGFloat) -> [PhotoGroup] {
        let threshold: Double
        if let visibleLatitudeDelta, mapHeight > 0 {
            threshold = visibleLatitudeDelta / Double(mapHeight) * Double(Self.markerSize)
        } else {
            threshold = 0.000225
        }
        var groups: [PhotoGroup] = []
        for pin in photoPins {
            let index = groups.firstIndex { group in
                let center = group.coordinate
                let longitudeScale = cos(center.latitude * .pi / 180)
                return abs(pin.coordinate.latitude - center.latitude) < threshold
                    && abs(pin.coordinate.longitude - center.longitude) * longitudeScale < threshold
            }
            if let index {
                groups[index].pins.append(pin)
            } else {
                groups.append(PhotoGroup(pins: [pin]))
            }
        }
        return groups
    }

    private func startEndMarker(systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(color)
            .background(Circle().fill(.white))
    }

    private func photoMarker(_ group: PhotoGroup) -> some View {
        Button {
            onSelectPhotos?(group.pins)
        } label: {
            Image(uiImage: group.pins[0].thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: Self.markerSize, height: Self.markerSize)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
                .overlay(alignment: .topTrailing) {
                    if group.pins.count > 1 {
                        Text("\(group.pins.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.red))
                            .offset(x: 8, y: -8)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.pins.count > 1 ? "\(group.pins.count) Fotos" : "Foto")
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
