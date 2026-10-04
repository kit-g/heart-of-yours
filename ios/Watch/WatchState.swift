import SwiftUI

/// What the phone last said to show (#182) — `lib/core/env/watch.dart`'s
/// `WatchState`, decoded. The phone is the only writer; this is a picture of
/// its state, never a copy to edit.
///
/// Every string is finished copy from Dart, which owns localisation and unit
/// formatting. The watch translates nothing.
enum WatchState: Equatable {
    /// Nothing from the phone yet: first launch, before the phone has answered.
    case awaiting
    case workout(Workout)
    /// No workout running.
    case idle(String)
    /// Switched off in the phone's Settings.
    case off(String)

    struct Workout: Equatable {
        var workoutId: String
        var startedAt: Date
        var title: String
        var exercise: String
        var next: String
        var rest: Rest?
        var accent: Color
        /// The set up next, which the watch can edit and tick (#183); nil when
        /// every set is done.
        var set: UpNext?
        /// The whole workout, for going back to a set already done (#175): the
        /// second page. Empty from a phone that predates it.
        var exercises: [Exercise] = []
        var controls: Controls?
        /// `WorkoutActivity`'s name for the session (#184).
        var activity: String?
        /// Where the elapsed clock counts from: [startedAt] moved on by every
        /// closed pause (#134). Nil from a phone that predates pauses.
        var clockStart: Date?
        /// While paused, when; the clock stands still.
        var pausedAt: Date?
        /// Whether pausing is on, on the phone: off, there is no control here.
        var pausable = false
        /// The pauses the workout has closed, for a workout session that joins
        /// the workout after them.
        var pauses: [ClosedRange<Date>] = []

        /// What the elapsed clock counts from.
        var clock: Date { clockStart ?? startedAt }

        struct UpNext: Equatable {
            var exerciseId: String
            var setId: String
            /// In [unit], as the phone shows it; nil for a set without weight.
            var weight: Double?
            /// Nil for a set that counts neither — ticked as prescribed.
            var reps: Int?
            var unit: String?
            /// One Digital Crown detent of weight.
            var step: Double
            /// The same set last session, as a finished line ("Last time: …").
            var previous: String?
            /// "Set 2 of 3".
            var position: String?
        }

        struct Exercise: Equatable, Identifiable {
            var id: String
            var name: String
            /// Nil for an exercise that takes no weight.
            var unit: String?
            var step: Double
            var weighted: Bool
            var counted: Bool
            /// Its rest timer, in seconds; nil for none. What a tick starts
            /// while the phone is out of reach (#206).
            var rest: Int?
            var sets: [Row]

            /// One set, done or not, in the exercise's [unit] — with the copy
            /// it is shown with once it is up next, for moving on to it while
            /// the phone is out of reach (#206).
            struct Row: Equatable, Identifiable {
                var id: String
                var weight: Double?
                var reps: Int?
                var done: Bool
                /// What the set column shows: "1", or "W" for a warm-up
                /// (#236). Empty from a phone that predates it.
                var mark: String = ""
                /// The type spelled out, for VoiceOver; nil for a plain set.
                var type: String?
                var position: String = ""
                var previous: String?
                var next: String = ""
            }

            init?(_ payload: Any) {
                guard let payload = payload as? [String: Any],
                      let id = payload["id"] as? String,
                      let name = payload["name"] as? String
                else { return nil }
                self.id = id
                self.name = name
                unit = payload["unit"] as? String
                step = (payload["step"] as? NSNumber)?.doubleValue ?? 1
                weighted = payload["weighted"] as? Bool ?? false
                counted = payload["counted"] as? Bool ?? false
                rest = (payload["rest"] as? NSNumber)?.intValue
                sets = (payload["sets"] as? [Any] ?? []).compactMap { row in
                    guard let row = row as? [String: Any], let id = row["id"] as? String else { return nil }
                    return Row(
                        id: id,
                        weight: (row["weight"] as? NSNumber)?.doubleValue,
                        reps: (row["reps"] as? NSNumber)?.intValue,
                        done: row["done"] as? Bool ?? false,
                        mark: row["mark"] as? String ?? "",
                        type: row["type"] as? String,
                        position: row["position"] as? String ?? "",
                        previous: row["previous"] as? String,
                        next: row["next"] as? String ?? ""
                    )
                }
            }

            init(
                id: String, name: String, unit: String?, step: Double, weighted: Bool, counted: Bool,
                rest: Int? = nil, sets: [Row]
            ) {
                (self.id, self.name, self.unit, self.step) = (id, name, unit, step)
                (self.weighted, self.counted, self.rest, self.sets) = (weighted, counted, rest, sets)
            }
        }

        struct Controls: Equatable {
            var done: String
            var skip: String
            var add: String
            var subtract: String
            var reps: String
            var unreachable: String
            var heartRate: String
            var bpm: String
            var energy: String
            var kcal: String
            var finish: String
            var finishTitle: String
            var finishConfirm: String
            var finishCancel: String
            var save: String
            var notDone: String
            /// What the watch says for itself while the phone is away (#206).
            var restLabel: String = ""
            var restOver: String = ""
            var allDone: String = ""
            var idle: String = ""
            var sending: String = ""
            var finishedAway: String = ""
            /// Stopping and starting the clock (#134), and the word for a
            /// stopped one.
            var pause: String = ""
            var resume: String = ""
            var paused: String = ""

            /// Nil unless every label the controls cannot do without is there;
            /// the rest default to empty, for a phone that predates them.
            init?(_ payload: [String: Any]) {
                func text(_ key: String) -> String? { payload[key] as? String }
                guard let done = text("done"),
                      let skip = text("skip"),
                      let add = text("add"),
                      let subtract = text("subtract"),
                      let reps = text("repsLabel"),
                      let unreachable = text("unreachable")
                else { return nil }
                self.done = done
                self.skip = skip
                self.add = add
                self.subtract = subtract
                self.reps = reps
                self.unreachable = unreachable
                heartRate = text("heartRate") ?? ""
                bpm = text("bpm") ?? ""
                energy = text("energy") ?? ""
                kcal = text("kcal") ?? ""
                finish = text("finish") ?? ""
                finishTitle = text("finishTitle") ?? ""
                finishConfirm = text("finishConfirm") ?? ""
                finishCancel = text("finishCancel") ?? ""
                save = text("save") ?? ""
                notDone = text("notDone") ?? ""
                restLabel = text("restLabelAway") ?? ""
                restOver = text("restOverAway") ?? ""
                allDone = text("allDone") ?? ""
                idle = text("idle") ?? ""
                sending = text("sending") ?? ""
                finishedAway = text("finishedAway") ?? ""
                pause = text("pause") ?? ""
                resume = text("resume") ?? ""
                paused = text("paused") ?? ""
            }

            init(
                done: String, skip: String, add: String, subtract: String, reps: String, unreachable: String,
                heartRate: String, bpm: String, energy: String, kcal: String,
                finish: String, finishTitle: String, finishConfirm: String, finishCancel: String,
                save: String, notDone: String
            ) {
                (self.done, self.skip, self.add, self.subtract, self.reps, self.unreachable) =
                    (done, skip, add, subtract, reps, unreachable)
                (self.heartRate, self.bpm, self.energy, self.kcal) = (heartRate, bpm, energy, kcal)
                (self.finish, self.finishTitle, self.finishConfirm, self.finishCancel) =
                    (finish, finishTitle, finishConfirm, finishCancel)
                (self.save, self.notDone) = (save, notDone)
            }
        }

        struct Rest: Equatable {
            var window: ClosedRange<Date>
            var label: String
            /// Shown once the countdown has run out and the phone has not been
            /// back to say so.
            var over: String
        }
    }

    /// Decodes a context or message as the phone sends it; nil for anything
    /// it doesn't recognise, which leaves the current state standing.
    init?(_ payload: [String: Any]) {
        func date(_ key: String) -> Date? {
            (payload[key] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        }

        switch payload["state"] as? String {
        case "idle":
            guard let message = payload["message"] as? String else { return nil }
            self = .idle(message)
        case "off":
            guard let message = payload["message"] as? String else { return nil }
            self = .off(message)
        case "workout":
            guard let workoutId = payload["workoutId"] as? String,
                  let startedAt = date("startedAt"),
                  let title = payload["title"] as? String,
                  let exercise = payload["exercise"] as? String,
                  let next = payload["next"] as? String
            else { return nil }

            let rest: Workout.Rest? = switch (date("restStart"), date("restEnd"), payload["restLabel"] as? String, payload["restOver"] as? String) {
            case let (start?, end?, label?, over?) where start < end:
                .init(window: start...end, label: label, over: over)
            default:
                nil
            }

            let set: Workout.UpNext? = switch (payload["exerciseId"] as? String, payload["setId"] as? String) {
            case let (exerciseId?, setId?):
                .init(
                    exerciseId: exerciseId,
                    setId: setId,
                    weight: (payload["weight"] as? NSNumber)?.doubleValue,
                    reps: (payload["reps"] as? NSNumber)?.intValue,
                    unit: payload["unit"] as? String,
                    step: (payload["step"] as? NSNumber)?.doubleValue ?? 1,
                    previous: payload["previous"] as? String,
                    position: payload["position"] as? String
                )
            default:
                nil
            }

            self = .workout(.init(
                workoutId: workoutId,
                startedAt: startedAt,
                title: title,
                exercise: exercise,
                next: next,
                rest: rest,
                accent: Color(argb: (payload["accent"] as? NSNumber)?.uint32Value ?? 0xFFFF_FFFF),
                set: set,
                exercises: (payload["exercises"] as? [Any] ?? []).compactMap(Workout.Exercise.init),
                controls: Workout.Controls(payload),
                activity: payload["activity"] as? String,
                clockStart: date("clockStart"),
                pausedAt: date("pausedAt"),
                pausable: payload["pausable"] as? Bool ?? false,
                pauses: (payload["pauses"] as? [Any] ?? []).compactMap { pause in
                    guard let pause = pause as? [String: Any],
                          let start = (pause["start"] as? NSNumber)?.doubleValue,
                          let end = (pause["end"] as? NSNumber)?.doubleValue,
                          start < end
                    else { return nil }
                    return Date(timeIntervalSince1970: start / 1000)...Date(timeIntervalSince1970: end / 1000)
                }
            ))
        default:
            return nil
        }
    }
}

extension Color {
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

/// The phone's last state with what the user did since, while the phone could
/// not hear it (#206): the same moves the phone would make, so the watch carries
/// on as if it had answered. The phone is still the only writer — this is only
/// what to show until its answer comes back, and its answer replaces it.
extension WatchState {
    func applying(_ command: PhoneSession.Command, at: Date) -> WatchState {
        guard case .workout(var workout) = self, workout.workoutId == command.workoutId else { return self }

        switch command {
        case let .complete(_, setId, weight, reps):
            // ticked already: the phone ignores it, and so does this
            guard let (e, r) = workout.locate(setId), !workout.exercises[e].sets[r].done else { return self }
            workout.exercises[e].sets[r].weight = weight ?? workout.exercises[e].sets[r].weight
            workout.exercises[e].sets[r].reps = reps ?? workout.exercises[e].sets[r].reps
            workout.exercises[e].sets[r].done = true
            // a tick is getting back to work: paused, the clock runs again
            workout.resume(at: at)
            workout.moveOn(after: (e, r))
            // the rest the tick starts, as the phone would start it — gone
            // already if the tick is older than the rest
            if let seconds = workout.exercises[e].rest, seconds > 0, let controls = workout.controls {
                let end = at.addingTimeInterval(TimeInterval(seconds))
                workout.rest = end > .now ? .init(window: at...end, label: controls.restLabel, over: controls.restOver) : nil
            }
        case let .edit(_, setId, weight, reps):
            guard let (e, r) = workout.locate(setId) else { return self }
            workout.exercises[e].sets[r].weight = weight ?? workout.exercises[e].sets[r].weight
            workout.exercises[e].sets[r].reps = reps ?? workout.exercises[e].sets[r].reps
        case let .untick(_, setId):
            // the phone keeps the set up next where it is, and so does this
            guard let (e, r) = workout.locate(setId) else { return self }
            workout.exercises[e].sets[r].done = false
        case .skipRest:
            workout.rest = nil
        case .pause:
            // pausing skips the rest, as on the phone
            if workout.pausedAt == nil {
                workout.pausedAt = at
                workout.rest = nil
            }
        case .resume:
            workout.resume(at: at)
        case let .adjustRest(_, seconds):
            if let rest = workout.rest {
                let end = rest.window.upperBound.addingTimeInterval(TimeInterval(seconds))
                workout.rest = end > max(rest.window.lowerBound, .now)
                    ? .init(window: rest.window.lowerBound...end, label: rest.label, over: rest.over)
                    : nil
            }
        case .finish:
            // finished here, with the phone away: say the workout is safe, not
            // that there is none — the phone's own idle line replaces it once
            // the phone has saved it
            return .idle(workout.controls.map { $0.finishedAway.isEmpty ? $0.idle : $0.finishedAway } ?? "")
        }
        return .workout(workout)
    }
}

private extension WatchState.Workout {
    /// Ends the pause, if there is one and [at] comes after it, by the phone's
    /// rule (`Workouts.resume`): the clock moves on by the time it stood still.
    mutating func resume(at: Date) {
        guard let pausedAt, at > pausedAt else { return }
        clockStart = clock.addingTimeInterval(at.timeIntervalSince(pausedAt))
        pauses.append(pausedAt...at)
        self.pausedAt = nil
    }

    /// Where [setId] is: its exercise's index and its own.
    func locate(_ setId: String) -> (Int, Int)? {
        for (e, exercise) in exercises.enumerated() {
            if let r = exercise.sets.firstIndex(where: { $0.id == setId }) { return (e, r) }
        }
        return nil
    }

    /// The set up next once [ticked] is done, by the phone's rule
    /// (`upNextIn` in `lib/core/utils/ongoing_workout.dart`): the next open set
    /// in the same exercise, else the first open set of a later one, else the
    /// first open set anywhere. Nothing open: every set is ticked.
    mutating func moveOn(after ticked: (Int, Int)) {
        let exercises = exercises
        func open(_ e: Int, from r: Int = 0) -> (Int, Int)? {
            let sets = exercises[e].sets
            guard r < sets.count else { return nil }
            return sets[r...].firstIndex(where: { !$0.done }).map { (e, $0) }
        }
        let (e, r) = ticked
        let upcoming = open(e, from: r + 1)
            ?? (e + 1 ..< exercises.count).lazy.compactMap { open($0) }.first
            ?? exercises.indices.lazy.compactMap { open($0) }.first

        guard let (ne, nr) = upcoming else {
            set = nil
            exercise = exercises[e].name
            next = controls?.allDone ?? ""
            return
        }
        let target = exercises[ne]
        let row = target.sets[nr]
        exercise = target.name
        next = row.next
        set = .init(
            exerciseId: target.id,
            setId: row.id,
            weight: row.weight,
            reps: row.reps,
            unit: target.unit,
            step: target.step,
            previous: row.previous,
            position: row.position
        )
    }
}
