import SwiftUI
import CoreLocation

struct LiveTrackingView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var trackStore: TrackStore

    @State private var showNamePrompt = false
    @State private var trackName = ""
    @State private var showSavedAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrackMapView(points: locationManager.currentTrack.points, isLive: true)
                    .frame(height: 280)

                ScrollView {
                    VStack(spacing: 16) {
                        if locationManager.authorizationStatus == .authorizedWhenInUse {
                            backgroundUpgradeBanner
                        }

                        StatsGridView()

                        if locationManager.currentTrack.points.count > 1 {
                            ProfileChartView(points: locationManager.currentTrack.points)
                                .padding(.horizontal)
                        }

                        controlButtons
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Live-Tracking")
            .onAppear {
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestPermission()
                }
                locationManager.startUpdating()
            }
            .onDisappear {
                // Keeps running while recording; otherwise no updates are needed off this tab.
                locationManager.stopUpdating()
            }
            .alert("Strecke speichern", isPresented: $showNamePrompt) {
                TextField("Name", text: $trackName)
                Button("Speichern") {
                    // A shortcut may have stopped and saved the recording meanwhile.
                    guard locationManager.isRecording else { return }
                    var track = locationManager.stopRecording()
                    track.name = trackName.isEmpty ? defaultName() : trackName
                    trackStore.save(track)
                    showSavedAlert = true
                }
                Button("Verwerfen", role: .destructive) {
                    locationManager.stopRecording()
                }
            } message: {
                Text("Gib der aufgezeichneten Strecke einen Namen.")
            }
            .alert("Strecke gespeichert", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var backgroundUpgradeBanner: some View {
        Button {
            locationManager.requestAlwaysPermission()
        } label: {
            HStack {
                Image(systemName: "moon.stars.fill")
                Text("Hintergrund-Tracking aktivieren")
                    .font(.footnote)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(10)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            if !locationManager.isRecording {
                Button {
                    trackName = defaultName()
                    locationManager.startRecording(name: trackName)
                } label: {
                    Label("Aufnahme starten", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    locationManager.isPaused ? locationManager.resumeRecording() : locationManager.pauseRecording()
                } label: {
                    Label(
                        locationManager.isPaused ? "Fortsetzen" : "Pause",
                        systemImage: locationManager.isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showNamePrompt = true
                } label: {
                    Label("Stopp", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
    }

    private func defaultName() -> String {
        Track.defaultName()
    }
}
