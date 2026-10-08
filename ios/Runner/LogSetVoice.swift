import AppIntents
import Foundation

/// A set logged by voice (#287): "Log a set in Heart", with the weight and
/// reps said, or the set's own. In the app's process with no app open; acts
/// on the set up next as Dart published it, answers the lock screen through
/// the Done button's transition, and hands Dart the tick — which ticks the
/// set for real, in kilograms, or drops a tick for a set already done.
@available(iOS 17, *)
enum LogSetVoice {
    /// The set up next as Dart published it (`ShortcutsChannel.setKey`).
    struct NextSet: Equatable {
        let workoutId: String
        let setId: String
        let exerciseName: String
        let weighted: Bool
        let counted: Bool
        let unit: String
        let weight: Double?
        let reps: Int?
        let completable: Bool

        init?(_ stored: Any?) {
            guard let map = stored as? [String: Any],
                  let workoutId = map["workoutId"] as? String,
                  let setId = map["setId"] as? String,
                  let exerciseName = map["exerciseName"] as? String,
                  let unit = map["unit"] as? String
            else { return nil }
            self.workoutId = workoutId
            self.setId = setId
            self.exerciseName = exerciseName
            self.weighted = map["weighted"] as? Bool ?? false
            self.counted = map["counted"] as? Bool ?? false
            self.unit = unit
            self.weight = (map["weight"] as? NSNumber)?.doubleValue
            self.reps = (map["reps"] as? NSNumber)?.intValue
            self.completable = map["completable"] as? Bool ?? false
        }
    }

    /// What was logged, or why nothing was.
    enum Outcome: Equatable {
        case logged(description: String)
        case noWorkout
        case nothingLeft
        case needsValues
    }

    /// The tick to hand Dart for [set] with [weight] and [reps] said — the
    /// set's own where nothing was — and what to say about it. Values a set
    /// does not take are left out, so a run's set hears no weight.
    static func plan(_ set: NextSet?, weight: Double?, reps: Int?) -> (command: [String: Any]?, outcome: Outcome) {
        guard let set else { return (nil, .noWorkout) }
        let weight = set.weighted ? (weight ?? set.weight) : nil
        let reps = set.counted ? (reps ?? set.reps) : nil
        // a set that cannot be ticked as it stands needs what was not said
        let filled = (!set.weighted || weight != nil) && (!set.counted || reps != nil)
        guard set.completable || filled else { return (nil, .needsValues) }

        var command: [String: Any] = [
            "action": "complete",
            "workoutId": set.workoutId,
            "setId": set.setId,
            "at": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if let weight { command["weight"] = weight }
        if let reps { command["reps"] = reps }
        return (command, .logged(description: describe(set, weight: weight, reps: reps)))
    }

    /// "100 kg × 5, Bench Press": the values in the unit they were said in.
    static func describe(_ set: NextSet, weight: Double?, reps: Int?) -> String {
        var parts: [String] = []
        if let weight {
            let number = weight == weight.rounded() ? String(Int(weight)) : String(format: "%.1f", weight)
            parts.append("\(number) \(set.unit)")
        }
        if let reps { parts.append("× \(reps)") }
        let values = parts.joined(separator: " ")
        return values.isEmpty ? set.exerciseName : "\(values), \(set.exerciseName)"
    }

    static func log(weight: Double?, reps: Int?, defaults: UserDefaults = .standard) async -> Outcome {
        let set = NextSet(defaults.object(forKey: ShortcutsChannel.setKey))
        // a workout with nothing left: Dart publishes the rest but no set
        if set == nil, RestVoice.Context(defaults.object(forKey: ShortcutsChannel.restKey)) != nil {
            return .nothingLeft
        }
        let (command, outcome) = plan(set, weight: weight, reps: reps)
        if let command, let set {
            await OngoingWorkoutIntents.complete(workoutId: set.workoutId, setId: set.setId, command: command)
        }
        return outcome
    }

    static func dialog(_ outcome: Outcome) -> IntentDialog {
        switch outcome {
        case let .logged(description):
            return IntentDialog("Logged \(description)")
        case .noWorkout:
            return IntentDialog("No workout is running")
        case .nothingLeft:
            return IntentDialog("Nothing left to log")
        case .needsValues:
            return IntentDialog("Say the weight and reps")
        }
    }
}

@available(iOS 17, *)
struct LogSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Set"

    @Parameter(title: "Weight")
    var weight: Double?

    @Parameter(title: "Reps")
    var reps: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$weight) by \(\.$reps)")
    }

    func perform() async throws -> some ProvidesDialog {
        let outcome = await LogSetVoice.log(weight: weight, reps: reps)
        return .result(dialog: LogSetVoice.dialog(outcome))
    }
}
