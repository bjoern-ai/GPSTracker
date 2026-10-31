import SwiftUI

/// Compact layout of the recording activity for places with little room,
/// e.g. CarPlay and the Apple Watch Smart Stack: large time, distance and
/// speed, readable at a glance. It has no buttons, because those places only
/// open the app on tap.
struct RecordingSmallView: View {
    let attributes: RecordingActivityAttributes
    let state: RecordingActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                Text(statusText)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))

            elapsed
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 8) {
                Text(RecordingActivityFormat.distance(state.distance))
                if !state.isFinished {
                    Spacer(minLength: 0)
                    Text(RecordingActivityFormat.speed(state.speed))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var elapsed: some View {
        if state.isFinished {
            Text(RecordingActivityFormat.duration(state.elapsed))
        } else {
            Text(timerInterval: attributes.startDate...Date.distantFuture, countsDown: false)
        }
    }

    private var statusText: String {
        if state.isFinished { return "Beendet" }
        return state.isPaused ? "Pausiert" : "Aufnahme läuft"
    }

    private var iconName: String {
        if state.isFinished { return "checkmark.circle.fill" }
        return state.isPaused ? "pause.circle.fill" : "record.circle"
    }

    private var iconColor: Color {
        if state.isFinished { return .green }
        return state.isPaused ? .orange : .red
    }
}
