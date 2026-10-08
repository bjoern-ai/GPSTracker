import SwiftUI

struct StatsGridView: View {
    @EnvironmentObject var locationManager: LocationManager

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        // Ticks once a second so the duration readout stays live while recording.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            LazyVGrid(columns: columns, spacing: 12) {
                StatCard(title: "Geschwindigkeit", value: speedText, icon: "speedometer")
                StatCard(title: "Höhe", value: altitudeText, icon: "mountain.2.fill")
                StatCard(title: "Distanz", value: distanceText, icon: "ruler")
                StatCard(title: "Dauer", value: durationText, icon: "clock")
            }
            .padding(.horizontal)
        }
    }

    private var speedText: String {
        String(format: "%.1f km/h", locationManager.currentSpeed * 3.6)
    }

    private var altitudeText: String {
        String(format: "%.0f m", locationManager.currentAltitude)
    }

    private var distanceText: String {
        String(format: "%.2f km", locationManager.currentTrack.distance / 1000)
    }

    private var durationText: String {
        guard locationManager.isRecording else { return "00:00:00" }
        let duration = Int(locationManager.currentTrack.duration)
        let h = duration / 3600
        let m = (duration % 3600) / 60
        let s = duration % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }
}
