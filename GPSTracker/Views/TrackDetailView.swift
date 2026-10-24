import SwiftUI
import PhotosUI

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
    @State private var publishStatus = "Wird hochgeladen …"
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoPins: [PhotoPin] = []
    @State private var photosWithoutLocation = 0
    @State private var selectedPhotoGroup: PhotoGroupSelection?
    @Environment(\.openURL) private var openURL
    @AppStorage(WordPressClient.siteURLKey) private var wordPressSite = ""
    @AppStorage(WordPressClient.usernameKey) private var wordPressUser = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TrackMapView(points: track.points, isLive: false, photoPins: photoPins) { pins in
                    selectedPhotoGroup = PhotoGroupSelection(pins: pins)
                }
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

                photoSection

                publishSection
            }
            .padding(.vertical)
        }
        .navigationTitle(track.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotos) {
            await loadPhotoPins()
        }
        .sheet(item: $selectedPhotoGroup) { selection in
            PhotoGallery(pins: selection.pins)
        }
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
            Text("Die Strecke wurde als Beitragsentwurf auf der Website angelegt. Prüfe ihn im WordPress-Editor, ergänze bei Bedarf weitere Fotos und veröffentliche den Beitrag.")
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

    @ViewBuilder
    private var publishSection: some View {
        if wordPressSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || wordPressUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Label("Um Strecken auf deiner WordPress-Website zu veröffentlichen, richte WordPress in den Einstellungen ein.", systemImage: "globe")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
        } else {
            publishControls
        }
    }

    /// Selected photos appear on the map and are uploaded when publishing.
    private var photoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PhotosPicker(selection: $selectedPhotos, selectionBehavior: .ordered, matching: .images) {
                        Label(photoSelectionText, systemImage: "photo.on.rectangle.angled")
                    }
                    Spacer()
                    if !selectedPhotos.isEmpty {
                        Button("Entfernen", role: .destructive) {
                            selectedPhotos = []
                        }
                    }
                }
                .disabled(isPublishing)

                if photosWithoutLocation > 0 {
                    Label(photosWithoutLocation == 1 ? "1 Foto ohne Ortsangabe" : "\(photosWithoutLocation) Fotos ohne Ortsangabe",
                          systemImage: "location.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text("Fotos")
        }
        .padding(.horizontal)
    }

    private var publishControls: some View {
        GroupBox {
            VStack(spacing: 12) {
                Button {
                    publish()
                } label: {
                    HStack {
                        if isPublishing {
                            ProgressView()
                            Text(publishStatus)
                        } else {
                            Label("Auf Website veröffentlichen", systemImage: "globe")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isPublishing)
            }
        } label: {
            Text("Website")
        }
        .padding(.horizontal)
    }

    private var photoSelectionText: String {
        switch selectedPhotos.count {
        case 0: return "Fotos auswählen"
        case 1: return "1 Foto ausgewählt"
        default: return "\(selectedPhotos.count) Fotos ausgewählt"
        }
    }

    /// Places the selected photos on the map. Runs again whenever the selection changes.
    private func loadPhotoPins() async {
        let items = selectedPhotos
        let track = track
        var pins: [PhotoPin] = []
        var withoutLocation = 0
        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                withoutLocation += 1
                continue
            }
            if Task.isCancelled { return }
            if let pin = await Task.detached(operation: { PhotoLocator.pin(id: index, data: data, track: track) }).value {
                pins.append(pin)
            } else {
                withoutLocation += 1
            }
        }
        if Task.isCancelled { return }
        photoPins = pins
        photosWithoutLocation = withoutLocation
    }

    private enum PhotoError: LocalizedError {
        case unreadable(Int)
        case upload(Int, Error)

        var errorDescription: String? {
            switch self {
            case .unreadable(let number):
                return "Foto \(number) konnte nicht gelesen oder umgewandelt werden. Der Beitrag wurde nicht erstellt."
            case .upload(let number, let error):
                return "Foto \(number) konnte nicht hochgeladen werden. Der Beitrag wurde nicht erstellt.\n\n\(error.localizedDescription)"
            }
        }
    }

    private func publish() {
        guard !isPublishing else { return }
        isPublishing = true
        publishStatus = "Strecke wird hochgeladen …"
        let photos = selectedPhotos
        Task {
            defer { isPublishing = false }
            do {
                let client = try WordPressClient.fromSettings()
                let track = track
                let gpx = await Task.detached { Data(GPXExporter.gpxString(for: track).utf8) }.value
                let mediaId = try await client.uploadGPX(gpx, fileName: WordPressClient.uploadFileName(for: track.name))

                var imageIds: [Int] = []
                for (index, item) in photos.enumerated() {
                    let number = index + 1
                    publishStatus = "Foto \(number) von \(photos.count) wird hochgeladen …"
                    guard let original = try? await item.loadTransferable(type: Data.self),
                          let jpeg = await Task.detached(operation: { PhotoConverter.jpegData(from: original) }).value else {
                        throw PhotoError.unreadable(number)
                    }
                    let fileName = WordPressClient.uploadFileName(for: "\(track.name) Foto \(number)", fileExtension: "jpg")
                    do {
                        imageIds.append(try await client.uploadPhoto(jpeg, fileName: fileName))
                    } catch {
                        throw PhotoError.upload(number, error)
                    }
                }

                publishStatus = "Beitrag wird erstellt …"
                let postId = try await client.createDraftPost(title: track.name, gpxId: mediaId, imageIds: imageIds)
                publishedPost = PublishedPost(id: postId, editURL: client.editURL(postId: postId))
                selectedPhotos = []
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

private struct PhotoGroupSelection: Identifiable {
    let pins: [PhotoPin]
    var id: Int { pins[0].id }
}

/// Large view of the photos behind a map marker; swipe for more than one.
private struct PhotoGallery: View {
    let pins: [PhotoPin]
    @State private var currentID: Int
    @Environment(\.dismiss) private var dismiss

    init(pins: [PhotoPin]) {
        self.pins = pins
        _currentID = State(initialValue: pins.first?.id ?? 0)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentID) {
                ForEach(pins) { pin in
                    PhotoPage(pin: pin)
                        .tag(pin.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pins.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var title: String {
        guard pins.count > 1, let index = pins.firstIndex(where: { $0.id == currentID }) else { return "Foto" }
        return "Foto \(index + 1) von \(pins.count)"
    }
}

private struct PhotoPage: View {
    let pin: PhotoPin
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 12) {
            Image(uiImage: image ?? pin.thumbnail)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .padding(.bottom, 32)
        .task {
            let data = pin.data
            image = await Task.detached { PhotoLocator.previewImage(from: data) }.value
        }
    }

    private var caption: String? {
        let date = pin.date?.formatted(.dateTime.day().month().year().hour().minute().locale(Locale(identifier: "de_DE")))
        switch (date, pin.isEstimated) {
        case (let date?, true): return "\(date) · Position aus der Aufnahmezeit geschätzt"
        case (let date?, false): return date
        case (nil, true): return "Position aus der Aufnahmezeit geschätzt"
        case (nil, false): return nil
        }
    }
}
