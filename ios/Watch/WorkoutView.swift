import SwiftUI

/// The workout in progress, as the phone summarised it (#182): where the user
/// is, what comes next, the rest countdown — and the controls to log the next
/// set and run the rest from here (#183).
///
/// The clocks are instants, never counts: the countdown and the elapsed time
/// tick here, natively, and the phone only speaks when something changes — the
/// same contract as the lock screen's Live Activity (#133).
struct WorkoutView: View {
    let workout: WatchState.Workout
    @EnvironmentObject private var phone: PhoneSession
    @EnvironmentObject private var session: WorkoutSession

    /// Wrist down, screen dimmed (#185) — only reachable while a workout
    /// session keeps the app frontmost. What is worth a glance stays: where
    /// the user is and how long the rest has left. The controls go, since
    /// nothing can be tapped until the wrist comes up, and the rest dims.
    @Environment(\.isLuminanceReduced) private var dimmed

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

                if let controls = workout.controls, session.workoutId == workout.workoutId {
                    Vitals(heartRate: session.heartRate, energy: session.energy, controls: controls)
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

                if let controls = workout.controls, !dimmed {
                    // absent, not dead: out of reach there is nothing a
                    // control could do, so there is none — only why
                    if phone.reachable {
                        if workout.rest != nil {
                            RestControls(workoutId: workout.workoutId, controls: controls)
                        }
                        if let set = workout.set {
                            SetControls(workoutId: workout.workoutId, set: set, controls: controls, accent: workout.accent)
                                .padding(.top, 4)
                        }
                    } else {
                        Text(controls.unreachable)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(dimmed ? 0.6 : 1)
        }
    }
}

/// What the watch's workout session measures (#184), as it measures it. Only
/// while Heart's own session runs — absent before the first reading, and for a
/// user who declined Health access, so it never shows a dash for "unknown".
struct Vitals: View {
    let heartRate: Double?
    let energy: Double?
    let controls: WatchState.Workout.Controls

    var body: some View {
        HStack(spacing: 10) {
            if let heartRate {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(Int(heartRate.rounded())) \(controls.bpm)")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(controls.heartRate)
                .accessibilityValue("\(Int(heartRate.rounded())) \(controls.bpm)")
            }
            if let energy {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(Int(energy.rounded())) \(controls.kcal)")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(controls.energy)
                .accessibilityValue("\(Int(energy.rounded())) \(controls.kcal)")
            }
        }
        .font(.footnote.monospacedDigit())
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

/// Shorter, longer, or over: the three things the phone's countdown offers.
struct RestControls: View {
    let workoutId: String
    let controls: WatchState.Workout.Controls
    @EnvironmentObject private var phone: PhoneSession

    var body: some View {
        HStack(spacing: 4) {
            Button(controls.subtract) { phone.send(.adjustRest(workoutId: workoutId, seconds: -10)) }
            Button(controls.add) { phone.send(.adjustRest(workoutId: workoutId, seconds: 10)) }
            Button(controls.skip) { phone.send(.skipRest(workoutId: workoutId)) }
        }
        .font(.footnote)
        .buttonStyle(.bordered)
        .disabled(phone.pending)
    }
}

/// The next set's values and its tick. The values start as the phone sent them
/// and the Digital Crown moves whichever one is focused; they only become the
/// set's when Done sends them — until the phone answers, nothing here claims
/// the set is done.
struct SetControls: View {
    let workoutId: String
    let set: WatchState.Workout.UpNext
    let controls: WatchState.Workout.Controls
    let accent: Color
    @EnvironmentObject private var phone: PhoneSession

    @State private var weight: Double = 0
    @State private var reps: Double = 0
    @FocusState private var focused: Field?

    private enum Field { case weight, reps }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if set.weight != nil || set.reps != nil {
                HStack(spacing: 6) {
                    if set.weight != nil, let unit = set.unit {
                        value(
                            weight.formatted(.number.precision(.fractionLength(0...2))),
                            unit: unit,
                            field: .weight
                        )
                        .digitalCrownRotation($weight, from: 0, through: 1000, by: set.step, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                        .accessibilityAdjustableAction { direction in
                            weight = max(0, weight + (direction == .increment ? set.step : -set.step))
                        }
                    }
                    if set.reps != nil {
                        value("\(Int(reps))", unit: controls.reps, field: .reps)
                            .digitalCrownRotation($reps, from: 0, through: 200, by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
                            .accessibilityAdjustableAction { direction in
                                reps = max(0, reps + (direction == .increment ? 1 : -1))
                            }
                    }
                }
            }

            if let previous = set.previous {
                Text(previous)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                phone.send(.complete(
                    workoutId: workoutId,
                    setId: set.setId,
                    // only what this set takes: a reps-only set sends no weight
                    weight: set.weight.map { _ in weight },
                    reps: set.reps.map { _ in Int(reps) }
                ))
            } label: {
                if phone.pending {
                    ProgressView()
                } else {
                    Text(controls.done)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            // a counted set needs a count; the phone would refuse it anyway
            .disabled(phone.pending || (set.reps != nil && reps < 1))
        }
        // a new set — or the same set sent again with new values — starts over
        .task(id: set) {
            weight = set.weight ?? 0
            reps = Double(set.reps ?? 0)
        }
    }

    private func value(_ text: String, unit: String, field: Field) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(.title3, design: .rounded).monospacedDigit())
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused == field ? accent : .clear, lineWidth: 2))
        .focusable()
        .focused($focused, equals: field)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(unit)
        .accessibilityValue(text)
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
        accent: .orange,
        set: .init(exerciseId: "e", setId: "s", weight: 62.5, reps: 5, unit: "kg", step: 2.5, previous: "Previous: 60 kg x 5"),
        controls: .init(
            done: "Done",
            skip: "Skip",
            add: "+10s",
            subtract: "-10s",
            reps: "Reps",
            unreachable: "Bring your iPhone closer to log from here",
            heartRate: "Heart rate",
            bpm: "bpm",
            energy: "Active energy",
            kcal: "kcal"
        ),
        activity: "strength"
    ))
    .environmentObject(PhoneSession())
    .environmentObject(WorkoutSession())
}
