import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock screen banner and Dynamic Island for a running recording.
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dauer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ElapsedText(context: context)
                            .font(.title3.bold())
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Distanz")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(RecordingActivityFormat.distance(context.state.distance))
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    StatusLabel(context: context)
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(RecordingActivityFormat.speed(context.state.speed), systemImage: "speedometer")
                            .font(.subheadline)
                            .monospacedDigit()
                        Spacer()
                        ControlButtons(context: context)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                StatusIcon(context: context)
            } compactTrailing: {
                ElapsedText(context: context)
                    .font(.caption.bold())
                    .frame(maxWidth: 56)
            } minimal: {
                StatusIcon(context: context)
            }
        }
    }
}

private typealias Context = ActivityViewContext<RecordingActivityAttributes>

private struct LockScreenView: View {
    let context: Context

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusLabel(context: context)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline) {
                ElapsedText(context: context)
                    .font(.system(size: 34, weight: .bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(RecordingActivityFormat.distance(context.state.distance))
                        .font(.title3.bold())
                    if !context.state.isFinished {
                        Text(RecordingActivityFormat.speed(context.state.speed))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
            }
            if !context.state.isFinished {
                ControlButtons(context: context)
            }
        }
        .foregroundStyle(.white)
    }
}

/// Elapsed time that ticks on its own while recording; fixed once finished.
private struct ElapsedText: View {
    let context: Context

    var body: some View {
        Group {
            if context.state.isFinished {
                Text(RecordingActivityFormat.duration(context.state.elapsed))
            } else {
                Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.leading)
    }
}

private struct StatusIcon: View {
    let context: Context

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(color)
    }

    private var color: Color {
        if context.state.isFinished { return .green }
        return context.state.isPaused ? .orange : .red
    }

    private var iconName: String {
        if context.state.isFinished { return "checkmark.circle.fill" }
        return context.state.isPaused ? "pause.circle.fill" : "record.circle"
    }
}

private struct StatusLabel: View {
    let context: Context

    var body: some View {
        HStack(spacing: 6) {
            StatusIcon(context: context)
            Text(statusText)
        }
    }

    private var statusText: String {
        if context.state.isFinished { return "Beendet · \(context.attributes.trackName)" }
        if context.state.isPaused { return "Pausiert · \(context.attributes.trackName)" }
        return context.attributes.trackName
    }
}

private struct ControlButtons: View {
    let context: Context

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: PauseResumeRecordingActivityIntent()) {
                Label(context.state.isPaused ? "Fortsetzen" : "Pause",
                      systemImage: context.state.isPaused ? "play.fill" : "pause.fill")
            }
            .tint(.orange)
            Button(intent: StopRecordingActivityIntent()) {
                Label("Stopp", systemImage: "stop.fill")
            }
            .tint(.red)
        }
        .buttonStyle(.borderedProminent)
        .font(.subheadline.weight(.semibold))
    }
}
