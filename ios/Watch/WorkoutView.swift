import SwiftUI

/// The workout in progress, as the phone summarised it (#182): where the user
/// is, what comes next, and the rest countdown.
///
/// The clocks are instants, never counts: the countdown and the elapsed time
/// tick here, natively, and the phone only speaks when something changes — the
/// same contract as the lock screen's Live Activity (#133).
struct WorkoutView: View {
    let workout: WatchState.Workout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.title)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(workout.startedAt, style: .timer)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if !workout.exercise.isEmpty {
                    Text(workout.exercise)
                        .font(.headline)
                        .foregroundStyle(workout.accent)
                        .lineLimit(2)
                }

                if !workout.next.isEmpty {
                    Text(workout.next)
                        .font(.body)
                        .lineLimit(2)
                }

                if let rest = workout.rest {
                    RestView(rest: rest, accent: workout.accent)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The rest countdown, and what it says once it has run out. The phone's next
/// update would take the rest away anyway; this covers the wait for it.
struct RestView: View {
    let rest: WatchState.Workout.Rest
    let accent: Color

    /// Flipped once, when the window closes — not a tick: the countdown
    /// itself is drawn by the system.
    @State private var over = false

    var body: some View {
        Group {
            if !over {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(rest.label)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(timerInterval: rest.window, countsDown: true)
                            .font(.system(.title2, design: .rounded).monospacedDigit())
                            .multilineTextAlignment(.trailing)
                    }
                    ProgressView(timerInterval: rest.window, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(accent)
                    .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text(rest.over)
                    .font(.headline)
                    .foregroundStyle(accent)
            }
        }
        // restarted whenever the window moves — an adjusted rest reopens it
        .task(id: rest.window) {
            let remaining = rest.window.upperBound.timeIntervalSinceNow
            over = remaining <= 0
            guard remaining > 0 else { return }
            try? await Task.sleep(for: .seconds(remaining))
            if !Task.isCancelled { over = true }
        }
    }
}

#Preview("Resting") {
    WorkoutView(workout: .init(
        workoutId: "w",
        startedAt: .now.addingTimeInterval(-1260),
        title: "Push day",
        exercise: "Bench Press (Barbell)",
        next: "Next: set 2 · 62.5 kg x 5",
        rest: .init(window: Date.now.addingTimeInterval(-30)...Date.now.addingTimeInterval(60), label: "Rest", over: "Rest complete!"),
        accent: .orange
    ))
}
