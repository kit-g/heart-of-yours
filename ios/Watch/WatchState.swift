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
            var sets: [Row]

            /// One set, done or not, in the exercise's [unit].
            struct Row: Equatable, Identifiable {
                var id: String
                var weight: Double?
                var reps: Int?
                var done: Bool
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
                sets = (payload["sets"] as? [Any] ?? []).compactMap { row in
                    guard let row = row as? [String: Any], let id = row["id"] as? String else { return nil }
                    return Row(
                        id: id,
                        weight: (row["weight"] as? NSNumber)?.doubleValue,
                        reps: (row["reps"] as? NSNumber)?.intValue,
                        done: row["done"] as? Bool ?? false
                    )
                }
            }

            init(id: String, name: String, unit: String?, step: Double, weighted: Bool, counted: Bool, sets: [Row]) {
                (self.id, self.name, self.unit, self.step) = (id, name, unit, step)
                (self.weighted, self.counted, self.sets) = (weighted, counted, sets)
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
                activity: payload["activity"] as? String
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
