import ActivityKit
import SwiftUI
import WidgetKit

@main
struct OngoingWorkoutBundle: WidgetBundle {
    var body: some Widget {
        OngoingWorkoutLiveActivity()
    }
}

/// The workout on the lock screen and in the Dynamic Island (#133).
///
/// Display only in v1: tapping opens the app, there are no buttons (#141).
/// Every clock here ticks on its own — `Text(timerInterval:)`, `Text(_:style:
/// .timer)`, `ProgressView(timerInterval:)` — so the app updates the activity
/// only when the workout changes.
struct OngoingWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OngoingWorkoutAttributes.self) { context in
            LockScreenView(context: context)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            // The island is always drawn on black, so it always takes the
            // dark half of the theme.
            let state = context.state
            let accent = Color(argb: state.accentDark)
            let ink = Color(argb: state.accentInkDark)
            let resting = state.rest != nil && !context.isStale

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HeartMark()
                        .fill(accent)
                        .frame(width: 22, height: 22)
                        .padding(.leading, 4)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Clock(context: context, resting: resting)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(ink)
                        .frame(maxWidth: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        ExerciseLines(state: state)
                        RestRow(state: state, isStale: context.isStale, accent: accent, ink: ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                HeartMark()
                    .fill(accent)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            } compactTrailing: {
                Clock(context: context, resting: resting)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ink)
                    .frame(maxWidth: 52)
            } minimal: {
                switch (resting, state.rest) {
                case (true, let rest?):
                    ProgressView(timerInterval: rest, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.circular)
                    .tint(accent)
                default:
                    HeartMark()
                        .fill(accent)
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
            }
            .keylineTint(accent)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<OngoingWorkoutAttributes>

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let state = context.state
        let (accent, ink) = switch scheme {
        case .dark: (Color(argb: state.accentDark), Color(argb: state.accentInkDark))
        default: (Color(argb: state.accent), Color(argb: state.accentInk))
        }

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HeartMark()
                    .fill(accent)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(context.attributes.startedAt, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90, alignment: .trailing)
            }
            ExerciseLines(state: state)
            RestRow(state: state, isStale: context.isStale, accent: accent, ink: ink)
        }
        .padding(16)
    }
}

/// The exercise and the set up next; either line is left out when empty.
private struct ExerciseLines: View {
    let state: OngoingWorkoutAttributes.ContentState

    var body: some View {
        if !state.exercise.isEmpty || !state.next.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                if !state.exercise.isEmpty {
                    Text(state.exercise)
                        .font(.headline)
                        .lineLimit(1)
                }
                if !state.next.isEmpty {
                    Text(state.next)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// The rest countdown, while one is running; once it has run out and the app
/// has not been back (the activity went stale at its end), the "over" copy.
private struct RestRow: View {
    let state: OngoingWorkoutAttributes.ContentState
    let isStale: Bool
    let accent: Color
    let ink: Color

    var body: some View {
        if let rest = state.rest {
            HStack(spacing: 10) {
                switch isStale {
                case true:
                    if let over = state.restOver {
                        Text(over)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ink)
                    }
                case false:
                    ProgressView(timerInterval: rest, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(accent)
                    if let label = state.restLabel {
                        Text(label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(timerInterval: rest, countsDown: true)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
    }
}

/// The one clock the compact island has room for: the rest countdown while
/// resting, the workout's elapsed time otherwise.
private struct Clock: View {
    let context: ActivityViewContext<OngoingWorkoutAttributes>
    let resting: Bool

    var body: some View {
        switch (resting, context.state.rest) {
        case (true, let rest?):
            Text(timerInterval: rest, countsDown: true)
                .multilineTextAlignment(.trailing)
        default:
            Text(context.attributes.startedAt, style: .timer)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Heart's mark: the same two curves as the launcher icon, the splash and
/// Android's status-bar icon (`res/drawable/ic_stat_heart.xml`), drawn in their
/// own 64-unit space and scaled to fit.
struct HeartMark: Shape {
    func path(in rect: CGRect) -> Path {
        // the curves span x 2...62, y 6.7...57.27 in the 64-unit space
        let bounds = CGRect(x: 2, y: 6.7, width: 60, height: 50.57)
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        let dx = rect.midX - bounds.midX * scale
        let dy = rect.midY - bounds.midY * scale
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + dx, y: y * scale + dy)
        }

        var path = Path()
        path.move(to: point(32, 13.42))
        path.addCurve(to: point(32, 57.27), control1: point(10.07, -8.51), control2: point(-22.82, 28.04))
        path.addCurve(to: point(32, 13.42), control1: point(86.82, 28.04), control2: point(53.93, -8.51))
        path.closeSubpath()
        return path
    }
}

extension Color {
    /// A Dart `Color.toARGB32()`.
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}
