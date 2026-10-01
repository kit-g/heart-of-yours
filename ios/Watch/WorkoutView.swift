import SwiftUI

/// The workout in progress, as the phone summarised it (#182), in two pages.
///
/// The first is the set up next, read top to bottom in the order it is used:
/// the exercise and which set, its values, last time's, the tick (#183) — then
/// the rest, and at the foot where the workout stands. The second, a swipe
/// away, is the whole workout, for going back to a set already done: new
/// values, or the tick taken off. Adding sets or exercises stays the phone's.
///
/// The clocks are instants, never counts: the countdown and the elapsed time
/// tick here, natively, and the phone only speaks when something changes — the
/// same contract as the lock screen's Live Activity (#133).
struct WorkoutView: View {
    let workout: WatchState.Workout

    /// Wrist down, screen dimmed (#185) — only reachable while a workout
    /// session keeps the app frontmost. Back to the set up next, which is
    /// what is worth a glance.
    @Environment(\.isLuminanceReduced) private var dimmed
    @State private var page = Page.upNext

    private enum Page { case upNext, workout }

    var body: some View {
        TabView(selection: $page) {
            UpNextPage(workout: workout)
                .tag(Page.upNext)
            // absent from a phone that predates it, rather than an empty page
            if !workout.exercises.isEmpty {
                WorkoutList(workout: workout)
                    .tag(Page.workout)
            }
        }
        .tabViewStyle(.page)
        .onChange(of: dimmed) { _, dimmed in
            if dimmed { page = .upNext }
        }
    }
}

/// The first page: the set up next, and everything about the moment.
struct UpNextPage: View {
    let workout: WatchState.Workout
    @EnvironmentObject private var phone: PhoneSession
    @EnvironmentObject private var session: WorkoutSession

    /// The controls go while dimmed, since nothing can be tapped until the
    /// wrist comes up, and the rest dims.
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if !workout.exercise.isEmpty {
                    Text(workout.exercise)
                        .font(.headline)
                        .foregroundStyle(workout.accent)
                        .lineLimit(2)
                }

                if let position = workout.set?.position {
                    Text(position)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let controls = workout.controls, !dimmed {
                    // out of reach too (#206): what is done here queues, and
                    // reaches the phone when it is back
                    if let set = workout.set {
                        SetControls(workoutId: workout.workoutId, set: set, controls: controls, accent: workout.accent)
                            .padding(.top, 2)
                    } else {
                        // every set ticked: the one thing left to do
                        FinishControl(workoutId: workout.workoutId, controls: controls, accent: workout.accent)
                            .padding(.top, 2)
                    }
                    if !phone.reachable || phone.waiting {
                        Label(controls.unreachable, systemImage: "iphone.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }

                if let rest = workout.rest {
                    RestView(rest: rest, accent: workout.accent)
                        .padding(.top, 6)
                    if let controls = workout.controls, !dimmed {
                        RestControls(workoutId: workout.workoutId, controls: controls)
                    }
                }

                footer
                    .padding(.top, 8)
                    // clear of the page dots, which float over the foot
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(dimmed ? 0.6 : 1)
        }
    }

    /// Where the workout stands: its name, how long it has run, and what the
    /// session measures.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.title)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(workout.startedAt, style: .timer)
                    .monospacedDigit()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let controls = workout.controls, session.workoutId == workout.workoutId {
                Vitals(heartRate: session.heartRate, energy: session.energy, controls: controls)
            }
        }
    }
}

/// The second page: every set of the workout, done or not. A set is a way in
/// to its editor while the phone can hear; out of reach it is only a line.
struct WorkoutList: View {
    let workout: WatchState.Workout
    @EnvironmentObject private var phone: PhoneSession
    @State private var editing: Editing?

    private struct Editing: Identifiable {
        let exercise: WatchState.Workout.Exercise
        let row: WatchState.Workout.Exercise.Row
        var id: String { row.id }
    }

    var body: some View {
        List {
            ForEach(workout.exercises) { exercise in
                Section {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, row in
                        if let controls = workout.controls {
                            Button {
                                editing = .init(exercise: exercise, row: row)
                            } label: {
                                line(index, row, of: exercise, controls: controls)
                            }
                        } else {
                            line(index, row, of: exercise, controls: workout.controls)
                        }
                    }
                } header: {
                    Text(exercise.name)
                        .textCase(nil)
                        .foregroundStyle(workout.accent)
                        .lineLimit(2)
                }
            }
        }
        .sheet(item: $editing) { editing in
            if let controls = workout.controls {
                SetEditor(
                    workoutId: workout.workoutId,
                    exercise: editing.exercise,
                    row: editing.row,
                    controls: controls,
                    accent: workout.accent
                )
            }
        }
        // the set changed under the editor — ticked or edited on the phone —
        // and what it would save is no longer what the user saw
        .onChange(of: workout.exercises) {
            editing = nil
        }
    }

    private func line(
        _ index: Int,
        _ row: WatchState.Workout.Exercise.Row,
        of exercise: WatchState.Workout.Exercise,
        controls: WatchState.Workout.Controls?
    ) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(row.id == workout.set?.setId ? workout.accent : .secondary)
                .frame(minWidth: 14, alignment: .leading)
            Text(WorkoutView.values(weight: row.weight, reps: row.reps, of: exercise, reps: controls?.reps ?? ""))
                .font(.body.monospacedDigit())
                .foregroundStyle(row.done ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            // on the watch, not yet on the phone (#206)
            if phone.unsynced.contains(row.id) {
                Image(systemName: "iphone.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(controls?.unreachable ?? "")
            }
            if row.done {
                Image(systemName: "checkmark")
                    .foregroundStyle(workout.accent)
                    .accessibilityLabel(controls?.done ?? "")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A set gone back to from the workout page. Done, it can take new values or
/// lose its tick; not done yet, it can be done from here, as the set up next
/// would be. Every button sends and closes: the list shows what the phone
/// makes of it.
struct SetEditor: View {
    let workoutId: String
    let exercise: WatchState.Workout.Exercise
    let row: WatchState.Workout.Exercise.Row
    let controls: WatchState.Workout.Controls
    let accent: Color
    @EnvironmentObject private var phone: PhoneSession
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 0
    @State private var reps: Double = 0
    @State private var field: ValueField?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(accent)
                        .lineLimit(2)

                    if exercise.weighted || exercise.counted {
                        HStack(spacing: 6) {
                            if exercise.weighted, let unit = exercise.unit {
                                ValuePill(text: WorkoutView.format(weight), unit: unit) { field = .weight }
                            }
                            if exercise.counted {
                                ValuePill(text: "\(Int(reps))", unit: controls.reps) { field = .reps }
                            }
                        }
                    }

                    if row.done {
                        Button {
                            if changed {
                                phone.send(.edit(workoutId: workoutId, setId: row.id, weight: sentWeight, reps: sentReps))
                            }
                            dismiss()
                        } label: {
                            Text(controls.save)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .frame(maxWidth: .infinity)
                        .disabled(exercise.counted && reps < 1)

                        Button(role: .destructive) {
                            phone.send(.untick(workoutId: workoutId, setId: row.id))
                            dismiss()
                        } label: {
                            Text(controls.notDone)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Button {
                            phone.send(.complete(workoutId: workoutId, setId: row.id, weight: sentWeight, reps: sentReps))
                            dismiss()
                        } label: {
                            Text(controls.done)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .frame(maxWidth: .infinity)
                        .disabled(exercise.counted && reps < 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationDestination(item: $field) { field in
                switch field {
                case .weight:
                    ValueEditor(value: $weight, step: exercise.step, unit: exercise.unit ?? "", accent: accent)
                case .reps:
                    ValueEditor(value: $reps, step: 1, unit: controls.reps, accent: accent)
                }
            }
        }
        .task {
            weight = row.weight ?? 0
            reps = Double(row.reps ?? 0)
        }
    }

    /// Only what the set takes: a reps-only set sends no weight.
    private var sentWeight: Double? { exercise.weighted ? weight : nil }
    private var sentReps: Int? { exercise.counted ? Int(reps) : nil }

    private var changed: Bool {
        sentWeight != row.weight || sentReps != row.reps
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
    }
}

/// The next set's values and its tick. The values start as the phone sent them
/// and the Digital Crown moves whichever one is focused; they only become the
/// set's when Done sends them. The watch moves on at once, and the phone's
/// answer — now, or once it is back in reach (#206) — is what stands.
struct SetControls: View {
    let workoutId: String
    let set: WatchState.Workout.UpNext
    let controls: WatchState.Workout.Controls
    let accent: Color
    @EnvironmentObject private var phone: PhoneSession

    @State private var weight: Double = 0
    @State private var reps: Double = 0
    /// The value open in the editor, if any.
    @State private var editing: ValueField?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if set.weight != nil || set.reps != nil {
                HStack(spacing: 6) {
                    if set.weight != nil, let unit = set.unit {
                        ValuePill(text: WorkoutView.format(weight), unit: unit) { editing = .weight }
                    }
                    if set.reps != nil {
                        ValuePill(text: "\(Int(reps))", unit: controls.reps) { editing = .reps }
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
                Text(controls.done)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            // the button, not only its label, spans the column — in a leading-
            // aligned stack it otherwise hugs the left edge
            .frame(maxWidth: .infinity)
            // a counted set needs a count; the phone would refuse it anyway
            .disabled(set.reps != nil && reps < 1)
        }
        // a new set — or the same set sent again with new values — starts over
        .task(id: set) {
            weight = set.weight ?? 0
            reps = Double(set.reps ?? 0)
        }
        .sheet(item: $editing) { field in
            switch field {
            case .weight:
                ValueEditor(value: $weight, step: set.step, unit: set.unit ?? "", accent: accent)
            case .reps:
                ValueEditor(value: $reps, step: 1, unit: controls.reps, accent: accent)
            }
        }
    }
}

/// Which of a set's values is open in its editor.
enum ValueField: Hashable, Identifiable {
    case weight, reps
    var id: Self { self }
}

/// A value on a set, shown as it will be logged; tapping it opens the editor.
/// Not edited in place: in a scrolling view the crown would scroll the page as
/// often as it changed the number, and nothing on a two-inch screen can say
/// "now turn the crown".
struct ValuePill: View {
    let text: String
    let unit: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(.title3, design: .rounded).monospacedDigit())
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(unit)
        .accessibilityValue(text)
    }
}

/// Finish, once every set is ticked, behind the phone's own question: it
/// cannot be undone from the wrist. The phone does the finishing — saves,
/// writes Health, shows the summary — and this goes idle when it has.
struct FinishControl: View {
    let workoutId: String
    let controls: WatchState.Workout.Controls
    let accent: Color
    @EnvironmentObject private var phone: PhoneSession
    @State private var confirming = false

    var body: some View {
        Button {
            confirming = true
        } label: {
            Text(controls.finish)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .frame(maxWidth: .infinity)
        .confirmationDialog(controls.finishTitle, isPresented: $confirming, titleVisibility: .visible) {
            Button(controls.finishConfirm) { phone.send(.finish(workoutId: workoutId)) }
            Button(controls.finishCancel, role: .cancel) {}
        }
    }
}

/// One value, full screen: − and + a step at a time, the Digital Crown for
/// bigger moves — focused from the start, with nothing else on screen to
/// scroll. The system's close button puts it away; the set's own Done is what
/// logs it.
struct ValueEditor: View {
    @Binding var value: Double
    let step: Double
    let unit: String
    let accent: Color
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(unit)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button { nudge(-1) } label: { Image(systemName: "minus") }
                    .accessibilityHidden(true)
                Text(WorkoutView.format(value))
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .focusable()
                    .focused($focused)
                    .digitalCrownRotation(
                        $value,
                        from: 0,
                        through: 1000,
                        by: step,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                    // the buttons are hidden from VoiceOver: this is the control
                    .accessibilityLabel(unit)
                    .accessibilityValue(WorkoutView.format(value))
                    .accessibilityAdjustableAction { direction in
                        nudge(direction == .increment ? 1 : -1)
                    }
                Button { nudge(1) } label: { Image(systemName: "plus") }
                    .accessibilityHidden(true)
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
        .task { focused = true }
    }

    private func nudge(_ steps: Double) {
        value = max(0, value + steps * step)
    }
}

extension WorkoutView {
    /// A weight or count as the watch shows it: whole when it is whole, up to
    /// two decimals otherwise (62.5, 1.25).
    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    /// A set's values on one line, as the workout page lists them: "60 kg × 5",
    /// "12 Reps", or nothing for a set that takes neither.
    static func values(weight: Double?, reps: Int?, of exercise: WatchState.Workout.Exercise, reps label: String) -> String {
        switch (exercise.weighted ? weight : nil, exercise.counted ? reps : nil) {
        case let (weight?, reps?): "\(format(weight)) \(exercise.unit ?? "") × \(reps)"
        case let (weight?, nil): "\(format(weight)) \(exercise.unit ?? "")"
        case let (nil, reps?): "\(reps) \(label)"
        case (nil, nil): ""
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
        accent: .orange,
        set: .init(
            exerciseId: "e", setId: "s2", weight: 62.5, reps: 5, unit: "kg", step: 2.5,
            previous: "Last time: 60 kg × 5", position: "Set 2 of 3"
        ),
        exercises: [
            .init(id: "e", name: "Bench Press (Barbell)", unit: "kg", step: 2.5, weighted: true, counted: true, sets: [
                .init(id: "s1", weight: 60, reps: 5, done: true),
                .init(id: "s2", weight: 62.5, reps: 5, done: false),
                .init(id: "s3", weight: 62.5, reps: 5, done: false),
            ]),
        ],
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
            kcal: "kcal",
            finish: "Finish",
            finishTitle: "Complete Your Workout?",
            finishConfirm: "Yes, I'm done!",
            finishCancel: "No, one more set!",
            save: "Save",
            notDone: "Not done"
        ),
        activity: "strength"
    ))
    .environmentObject(PhoneSession())
    .environmentObject(WorkoutSession())
}
