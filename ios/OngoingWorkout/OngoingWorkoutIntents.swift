import ActivityKit
import AppIntents
import Foundation
import UserNotifications

/// The rest buttons on the lock screen and in the Dynamic Island (#141):
/// ten seconds off, ten on, skip. `LiveActivityIntent`s run in the app's
/// process — with or without a Flutter engine up — so each one answers the
/// lock screen itself first, then hands the command to Dart, which applies it
/// the way the watch's are applied and sends the state that results.
///
/// Compiled into both the app and the widget extension, like the attributes:
/// the extension needs the types to draw the buttons, the app runs them.
/// What needs the app — the channel to Dart — is reached through [handoff],
/// which the app sets at launch and the extension never does.
@available(iOS 17, *)
enum OngoingWorkoutIntents {
    /// Hands a command to Dart, or keeps it until Dart asks. Set by the app
    /// (`OngoingWorkoutChannel`); nil in the extension, where nothing runs.
    nonisolated(unsafe) static var handoff: (([String: Any]) -> Void)?

    /// The pending "rest complete" notification's identifier: Dart's id 0, as
    /// flutter_local_notifications names its requests.
    static let restNotification = "0"

    /// Moves the rest's end by [seconds] on the activity for [workoutId] — or
    /// ends the rest, for nil — and reschedules or withdraws the "rest
    /// complete" notification to match. Then the command goes to Dart.
    static func rest(workoutId: String, seconds: Int?) async {
        for activity in Activity<OngoingWorkoutAttributes>.activities
        where activity.attributes.workoutId == workoutId {
            guard let state = adjusted(activity.content.state, by: seconds) else { continue }
            await activity.update(ActivityContent(state: state, staleDate: state.restEnd))
            switch state.restEnd {
            case let moved?:
                await reschedule(to: moved)
            case nil:
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restNotification])
            }
        }

        var command: [String: Any] = [
            "action": seconds == nil ? "skipRest" : "adjustRest",
            "workoutId": workoutId,
            "at": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if let seconds { command["seconds"] = seconds }
        handoff?(command)
    }

    /// [state] with its rest moved by [seconds], or over for nil: every rest
    /// field cleared, so the view draws no rest row and no buttons. Nil when
    /// there is no rest to act on — a button pressed after the rest ended.
    static func adjusted(_ state: OngoingWorkoutAttributes.ContentState, by seconds: Int?) -> OngoingWorkoutAttributes.ContentState? {
        guard let end = state.restEnd else { return nil }
        var state = state
        switch seconds {
        case let seconds?:
            state.restEnd = end.addingTimeInterval(TimeInterval(seconds))
        case nil:
            state.restStart = nil
            state.restEnd = nil
            state.restLabel = nil
            state.restOver = nil
            state.restMinus = nil
            state.restPlus = nil
            state.restSkip = nil
        }
        return state
    }

    /// The pending "rest complete" notification, moved to [date]: the same
    /// content, a new trigger. A rest moved into the past fires at once,
    /// which is what a rest that is over deserves.
    private static func reschedule(to date: Date) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard let request = pending.first(where: { $0.identifier == restNotification }) else { return }
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: max(date, Date().addingTimeInterval(1))
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let moved = UNNotificationRequest(identifier: request.identifier, content: request.content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [restNotification])
        try? await center.add(moved)
    }
}

@available(iOS 17, *)
struct AdjustRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Adjust Rest"
    static let isDiscoverable = false

    @Parameter(title: "Workout")
    var workoutId: String

    @Parameter(title: "Seconds")
    var seconds: Int

    init() {
        workoutId = ""
        seconds = 0
    }

    init(workoutId: String, seconds: Int) {
        self.workoutId = workoutId
        self.seconds = seconds
    }

    func perform() async throws -> some IntentResult {
        await OngoingWorkoutIntents.rest(workoutId: workoutId, seconds: seconds)
        return .result()
    }
}

@available(iOS 17, *)
struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Rest"
    static let isDiscoverable = false

    @Parameter(title: "Workout")
    var workoutId: String

    init() {
        workoutId = ""
    }

    init(workoutId: String) {
        self.workoutId = workoutId
    }

    func perform() async throws -> some IntentResult {
        await OngoingWorkoutIntents.rest(workoutId: workoutId, seconds: nil)
        return .result()
    }
}
