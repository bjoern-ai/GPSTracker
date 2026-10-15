import SwiftUI

struct TrackDetailView: View {
    let track: Track

    private struct ExportFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    private struct PublishedPost: Identifiable {
        let id: Int
        let editURL: URL
    }

    @State private var exportFile: ExportFile?
    @State private var isPublishing = false
    @State private var publishedPost: PublishedPost?
    @State private var publishError: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TrackMapView(points: track.points, isLive: false)
                    .frame(height: 250)

                statsSection

                if track.points.count > 1 {
                    ProfileChartView(points: track.points)
                        .padding(.horizontal)
                }

                Button {
                    if let url = GPXExporter.exportToFile(track: track) {
                        exportFile = ExportFile(url: url)
                    }
                } label: {
                    Label("Als GPX exportieren", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Button {
                    publish()
                } label: {
                    HStack {
                        if isPublishing {
                            ProgressView()
                            Text("Wird hochgeladen …")
                        } else {
                            Label("Auf Website veröffentlichen", systemImage: "globe")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isPublishing)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(track.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
        }
        .alert("Entwurf erstellt", isPresented: Binding(
            get: { publishedPost != nil },
            set: { if !$0 { publishedPost = nil } }
        ), presenting: publishedPost) { post in
            Button("Im Editor öffnen") { openURL(post.editURL) }
            Button("Schließen", role: .cancel) {}
        } message: { _ in
            Text("Die Strecke wurde als Beitragsentwurf auf der Website angelegt. Füge im WordPress-Editor Fotos hinzu und veröffentliche den Beitrag.")
        }
        .alert("Veröffentlichen fehlgeschlagen", isPresented: Binding(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(publishError ?? "")
        }
    }

    private func publish() {
        guard !isPublishing else { return }
        isPublishing = true
        Task {
            defer { isPublishing = false }
            do {
                let client = try WordPressClient.fromSettings()
                let gpx = Data(GPXExporter.gpxString(for: track).utf8)
                let mediaId = try await client.uploadGPX(gpx, fileName: WordPressClient.uploadFileName(for: track.name))
                let postId = try await client.createDraftPost(title: track.name, gpxId: mediaId)
                publishedPost = PublishedPost(id: postId, editURL: client.editURL(postId: postId))
            } catch {
                publishError = error.localizedDescription
            }
        }
    }

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Distanz", value: String(format: "%.2f km", track.distance / 1000), icon: "ruler")
            StatCard(title: "Dauer", value: durationText, icon: "clock")
            StatCard(title: "Ø Geschwindigkeit", value: String(format: "%.1f km/h", track.averageSpeed * 3.6), icon: "speedometer")
            StatCard(title: "Max. Geschwindigkeit", value: String(format: "%.1f km/h", track.maxSpeed * 3.6), icon: "gauge.with.dots.needle.67percent")
            StatCard(title: "Höhengewinn", value: String(format: "%.0f m", track.elevationGain), icon: "arrow.up.right")
            StatCard(title: "Max. Höhe", value: String(format: "%.0f m", track.maxAltitude), icon: "mountain.2.fill")
        }
        .padding(.horizontal)
    }

    private var durationText: String {
        let duration = Int(track.duration)
        let h = duration / 3600
        let m = (duration % 3600) / 60
        let s = duration % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
