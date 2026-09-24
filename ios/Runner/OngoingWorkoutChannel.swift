import ActivityKit
import Flutter
import os

/// The app's half of the workout Live Activity (#133): the `heart/ongoing_workout`
/// channel that `lib/core/env/ongoing_workout.dart` speaks to.
///
/// `show` starts the activity or updates the one already up; `end` takes every
/// one down. Anything ActivityKit refuses — an iPad, the user's per-app switch,
/// iOS below 16.2 — is answered with success and nothing drawn: a lock screen
/// that cannot be shown is never the workout's problem.
enum OngoingWorkoutChannel {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "heart/ongoing_workout", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard #available(iOS 16.2, *) else { return result(nil) }

            switch call.method {
            case "show":
                guard let arguments = call.arguments as? [String: Any],
                      let request = OngoingWorkoutRequest(arguments)
                else {
                    return result(FlutterError(code: "bad_arguments", message: "show needs a workout", details: nil))
                }
                Task {
                    await OngoingWorkoutActivities.show(request)
                    result(nil)
                }
            case "end":
                Task {
                    await OngoingWorkoutActivities.end()
                    result(nil)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

private let log = Logger(subsystem: "me.heart-of", category: "OngoingWorkout")

@available(iOS 16.1, *)
struct OngoingWorkoutRequest {
    let workoutId: String
    let startedAt: Date
    let state: OngoingWorkoutAttributes.ContentState

    init?(_ arguments: [String: Any]) {
        guard let workoutId = arguments["workoutId"] as? String,
              let startedAt = (arguments["startedAt"] as? NSNumber).map(Self.date),
              let title = arguments["title"] as? String,
              let exercise = arguments["exercise"] as? String,
              let next = arguments["next"] as? String
        else { return nil }

        func color(_ key: String) -> UInt32 {
            (arguments[key] as? NSNumber)?.uint32Value ?? 0xFFFF_FFFF
        }

        self.workoutId = workoutId
        self.startedAt = startedAt
        self.state = .init(
            title: title,
            exercise: exercise,
            next: next,
            restStart: (arguments["restStart"] as? NSNumber).map(Self.date),
            restEnd: (arguments["restEnd"] as? NSNumber).map(Self.date),
            restLabel: arguments["restLabel"] as? String,
            restOver: arguments["restOver"] as? String,
            accent: color("accent"),
            accentDark: color("accentDark"),
            accentInk: color("accentInk"),
            accentInkDark: color("accentInkDark")
        )
    }

    private static func date(_ milliseconds: NSNumber) -> Date {
        Date(timeIntervalSince1970: milliseconds.doubleValue / 1000)
    }
}

@available(iOS 16.2, *)
enum OngoingWorkoutActivities {
    typealias WorkoutActivity = Activity<OngoingWorkoutAttributes>

    /// Starts the workout's activity, or updates it if one is already up —
    /// including one left behind by a process that was killed mid-workout,
    /// which is found again by the workout's id. Activities for any other
    /// workout are strays and go.
    static func show(_ request: OngoingWorkoutRequest) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // stale at the rest's end, so the view can say it is over even if the
        // app is suspended by then and cannot send the update itself
        let content = ActivityContent(state: request.state, staleDate: request.state.restEnd)
        let live = WorkoutActivity.activities.filter { $0.activityState == .active || $0.activityState == .stale }

        for stray in live where stray.attributes.workoutId != request.workoutId {
            await stray.end(nil, dismissalPolicy: .immediate)
        }

        if let current = live.first(where: { $0.attributes.workoutId == request.workoutId }) {
            await current.update(content)
            return
        }

        do {
            _ = try WorkoutActivity.request(
                attributes: .init(workoutId: request.workoutId, startedAt: request.startedAt),
                content: content,
                pushType: nil
            )
        } catch {
            log.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func end() async {
        for activity in WorkoutActivity.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
