import ActivityKit
import AppIntents
import Foundation
import UserNotifications

/// The rest timer by voice (#98): start, extend and skip, said to Siri with
/// the phone across the rack. Route A of the ticket — no microphone, no
/// listening of the app's own: the system hears, these act.
///
/// They act with the app possibly not running, on what Dart leaves for them:
/// the rest the user is on (`ShortcutsChannel.restKey`: workout, exercise,
/// its rest setting, the notification's words) and the rest in progress
/// (`flutter.rest.*`, the app's own store, which the app restores on launch).
/// Each answers the lock screen (the Live Activity, through the same
/// transitions its buttons use) and the notification first, then hands the
/// command to Dart, which applies it the way the watch's are applied.
@available(iOS 17, *)
enum RestVoice {
    /// Dart's RestStore (#141), as shared_preferences names its keys.
    static let restExerciseKey = "flutter.rest.exerciseId"
    static let restEndKey = "flutter.rest.end"
    static let restTotalKey = "flutter.rest.total"

    /// What Dart published: the workout and exercise the user is on, the
    /// exercise's rest setting, the notification's words.
    struct Context {
        let workoutId: String
        let exerciseId: String
        let seconds: Int?
        let title: String
        let body: String?
        let subtitle: String

        init?(_ stored: Any?) {
            guard let map = stored as? [String: Any],
                  let workoutId = map["workoutId"] as? String,
                  let exerciseId = map["exerciseId"] as? String,
                  let title = map["title"] as? String,
                  let subtitle = map["subtitle"] as? String
            else { return nil }
            self.workoutId = workoutId
            self.exerciseId = exerciseId
            self.seconds = (map["seconds"] as? NSNumber)?.intValue
            self.title = title
            self.body = map["body"] as? String
            self.subtitle = subtitle
        }
    }

    /// The rest in progress as the app's store has it: its end, if still
    /// ahead of [now].
    static func runningRest(in defaults: UserDefaults, now: Date = Date()) -> (exerciseId: String, end: Date, total: Int)? {
        guard let exerciseId = defaults.string(forKey: restExerciseKey),
              let millis = defaults.object(forKey: restEndKey) as? NSNumber
        else { return nil }
        let end = Date(timeIntervalSince1970: millis.doubleValue / 1000)
        guard end > now else { return nil }
        return (exerciseId, end, defaults.integer(forKey: restTotalKey))
    }

    /// What a voice command did, for Siri to say.
    enum Outcome: Equatable {
        case started(seconds: Int)
        case extended(by: Int, left: Int)
        case skipped
        case noWorkout
        case noRest
        case noTimer
    }

    /// Starts a rest for [seconds], or the exercise's own setting for nil.
    /// Mirrors what Dart will do on the app's store, so a launch in the
    /// meantime restores the same rest; schedules the notification Dart
    /// would have; moves the Live Activity on; hands Dart the command.
    static func start(seconds: Int?, defaults: UserDefaults = .standard, now: Date = Date()) async -> Outcome {
        guard let context = Context(defaults.object(forKey: ShortcutsChannel.restKey)) else { return .noWorkout }
        guard let length = seconds ?? context.seconds, length > 0 else { return .noTimer }
        let end = now.addingTimeInterval(TimeInterval(length))
        defaults.set(context.exerciseId, forKey: restExerciseKey)
        defaults.set(Int(end.timeIntervalSince1970 * 1000), forKey: restEndKey)
        defaults.set(length, forKey: restTotalKey)
        await OngoingWorkoutIntents.schedule(
            .init(title: context.title, body: context.body, subtitle: context.subtitle, exerciseId: context.exerciseId, at: end)
        )
        await OngoingWorkoutIntents.startRest(workoutId: context.workoutId, seconds: length, at: now)
        OngoingWorkoutIntents.handoff?([
            "action": "startRest",
            "workoutId": context.workoutId,
            "seconds": length,
            "at": Int(now.timeIntervalSince1970 * 1000),
        ])
        return .started(seconds: length)
    }

    /// Moves the running rest's end by [seconds].
    static func extend(by seconds: Int, defaults: UserDefaults = .standard, now: Date = Date()) async -> Outcome {
        guard let context = Context(defaults.object(forKey: ShortcutsChannel.restKey)) else { return .noWorkout }
        guard let rest = runningRest(in: defaults, now: now) else { return .noRest }
        let end = rest.end.addingTimeInterval(TimeInterval(seconds))
        defaults.set(Int(end.timeIntervalSince1970 * 1000), forKey: restEndKey)
        defaults.set(max(0, rest.total + seconds), forKey: restTotalKey)
        await OngoingWorkoutIntents.rest(workoutId: context.workoutId, seconds: seconds)
        return .extended(by: seconds, left: max(0, Int(end.timeIntervalSince(now))))
    }

    /// Ends the running rest.
    static func skip(defaults: UserDefaults = .standard, now: Date = Date()) async -> Outcome {
        guard let context = Context(defaults.object(forKey: ShortcutsChannel.restKey)) else { return .noWorkout }
        guard runningRest(in: defaults, now: now) != nil else { return .noRest }
        defaults.removeObject(forKey: restExerciseKey)
        defaults.removeObject(forKey: restEndKey)
        defaults.removeObject(forKey: restTotalKey)
        await OngoingWorkoutIntents.rest(workoutId: context.workoutId, seconds: nil)
        return .skipped
    }

    /// "1:30", for Siri to say after the word.
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// How long a rest, said to Siri: the lengths people ask for.
@available(iOS 17, *)
enum RestLength: String, AppEnum {
    case thirtySeconds
    case oneMinute
    case ninetySeconds
    case twoMinutes
    case threeMinutes

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Rest length")
    static let caseDisplayRepresentations: [RestLength: DisplayRepresentation] = [
        .thirtySeconds: "30 seconds",
        .oneMinute: "1 minute",
        .ninetySeconds: "90 seconds",
        .twoMinutes: "2 minutes",
        .threeMinutes: "3 minutes",
    ]

    var seconds: Int {
        switch self {
        case .thirtySeconds: 30
        case .oneMinute: 60
        case .ninetySeconds: 90
        case .twoMinutes: 120
        case .threeMinutes: 180
        }
    }
}

@available(iOS 17, *)
struct StartRestIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Rest"

    @Parameter(title: "Length")
    var length: RestLength?

    func perform() async throws -> some ProvidesDialog {
        let outcome = await RestVoice.start(seconds: length?.seconds)
        return .result(dialog: RestVoice.dialog(outcome))
    }
}

@available(iOS 17, *)
struct AddRestIntent: AppIntent {
    static let title: LocalizedStringResource = "Extend Rest"

    @Parameter(title: "Length", default: .thirtySeconds)
    var length: RestLength

    func perform() async throws -> some ProvidesDialog {
        let outcome = await RestVoice.extend(by: length.seconds)
        return .result(dialog: RestVoice.dialog(outcome))
    }
}

@available(iOS 17, *)
struct EndRestIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip Rest"

    func perform() async throws -> some ProvidesDialog {
        let outcome = await RestVoice.skip()
        return .result(dialog: RestVoice.dialog(outcome))
    }
}

@available(iOS 17, *)
extension RestVoice {
    /// What Siri says. The words are the catalog's (`Localizable.xcstrings`,
    /// from the translations flow); the clock is digits.
    static func dialog(_ outcome: Outcome) -> IntentDialog {
        switch outcome {
        case let .started(seconds):
            return IntentDialog("Resting \(clock(seconds))")
        case let .extended(_, left):
            return IntentDialog("Rest extended, \(clock(left)) left")
        case .skipped:
            return IntentDialog("Rest skipped")
        case .noWorkout:
            return IntentDialog("No workout is running")
        case .noRest:
            return IntentDialog("No rest is running")
        case .noTimer:
            return IntentDialog("This exercise has no rest timer")
        }
    }
}
