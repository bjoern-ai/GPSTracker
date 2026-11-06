import CarPlay
import Combine

/// CarPlay screen for a recording: time, distance, speed and the controls to
/// start, pause and stop. It runs on the same `LocationManager` as the iPhone
/// app. CarPlay only allows fixed templates here, so there is no map.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private enum Controls {
        case start, pause, resume
    }

    private let locationManager = LocationManager.shared
    private var subscriptions = Set<AnyCancellable>()
    private var template: CPInformationTemplate?
    private var shownRows: [[String]] = []
    private var shownControls: Controls?
    private var message: String?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        let template = CPInformationTemplate(title: "Tourspur", layout: .twoColumn, items: [], actions: [])
        self.template = template
        refresh()
        interfaceController.setRootTemplate(template, animated: false, completion: nil)

        // The publishers fire before the value changes, so read it on the next run of the main queue.
        locationManager.$isRecording.map { _ in }
            .merge(with: locationManager.$isPaused.map { _ in })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.refresh() }
            .store(in: &subscriptions)
        Timer.publish(every: 3, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &subscriptions)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        subscriptions.removeAll()
        template = nil
        shownRows = []
        shownControls = nil
    }

    private var controls: Controls {
        guard locationManager.isRecording else { return .start }
        return locationManager.isPaused ? .resume : .pause
    }

    private var rows: [[String]] {
        var rows: [[String]]
        if locationManager.isRecording {
            let track = locationManager.currentTrack
            rows = [
                ["Status", locationManager.isPaused ? "Pausiert" : "Aufnahme läuft"],
                ["Dauer", RecordingActivityFormat.duration(track.duration)],
                ["Distanz", RecordingActivityFormat.distance(track.distance)],
                ["Tempo", RecordingActivityFormat.speed(locationManager.isPaused ? 0 : locationManager.currentSpeed)],
            ]
        } else {
            rows = [["Status", "Bereit"]]
        }
        if let message {
            rows.append(["Hinweis", message])
        }
        return rows
    }

    /// Only touches the template when something changed, so the screen doesn't flicker.
    private func refresh() {
        guard let template else { return }
        let rows = rows
        if rows != shownRows {
            shownRows = rows
            template.items = rows.map { CPInformationItem(title: $0[0], detail: $0[1]) }
        }
        if controls != shownControls {
            shownControls = controls
            template.actions = actions(for: controls)
        }
    }

    private func actions(for controls: Controls) -> [CPTextButton] {
        switch controls {
        case .start:
            return [button("Aufnahme starten", style: .confirm) { $0.startRecording() }]
        case .pause:
            return [button("Pause") { $0.locationManager.pauseRecording() }, stopButton]
        case .resume:
            return [button("Fortsetzen", style: .confirm) { $0.locationManager.resumeRecording() }, stopButton]
        }
    }

    private var stopButton: CPTextButton {
        button("Stopp", style: .cancel) { $0.message = RecordingControl.stop() }
    }

    private func button(_ title: String, style: CPTextButtonStyle = .normal,
                        action: @escaping (CarPlaySceneDelegate) -> Void) -> CPTextButton {
        CPTextButton(title: title, textStyle: style) { [weak self] _ in
            guard let self else { return }
            action(self)
            self.refresh()
        }
    }

    private func startRecording() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            message = nil
            locationManager.startRecording(name: Track.defaultName())
        default:
            message = "Bitte erlaube den Standortzugriff in Tourspur auf dem iPhone."
        }
    }
}
