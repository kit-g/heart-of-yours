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

    /// Ticks [setId] on the activity for [workoutId] (#246): the lines that
    /// follow take over, the exercise's rest starts with the notification
    /// the app would have scheduled for its end, and the Done button goes
    /// until the app says what is next. Then the command goes to Dart, which
    /// ticks the set for real — or drops a tick for a set already done.
    static func complete(workoutId: String, setId: String) async {
        for activity in Activity<OngoingWorkoutAttributes>.activities
        where activity.attributes.workoutId == workoutId {
            let now = Date()
            guard let (state, notification) = completed(activity.content.state, setId: setId, at: now) else { continue }
            await activity.update(ActivityContent(state: state, staleDate: state.restEnd))
            if let notification { await schedule(notification) }
        }

        handoff?([
            "action": "complete",
            "workoutId": workoutId,
            "setId": setId,
            "at": Int(Date().timeIntervalSince1970 * 1000),
        ])
    }

    /// The "rest complete" notification a tick schedules, as Dart would.
    struct RestNotification: Equatable {
        let title: String
        let body: String?
        let subtitle: String
        let exerciseId: String
        let at: Date
    }

    /// [state] once [setId] is ticked at [at], and the notification for the
    /// rest it starts — nil when the state's Done is not for [setId]: the
    /// app has moved on, and the tick is stale.
    static func completed(
        _ state: OngoingWorkoutAttributes.ContentState,
        setId: String,
        at: Date
    ) -> (OngoingWorkoutAttributes.ContentState, RestNotification?)? {
        guard state.doneSetId == setId, let exerciseId = state.doneExerciseId else { return nil }
        var next = state
        next.exercise = state.afterExercise ?? ""
        next.next = state.afterNext ?? ""
        next.stopwatchStart = nil
        next.stopwatchLabel = nil
        next.stopwatchPausedAt = nil
        var notification: RestNotification?
        switch state.afterRest {
        case let seconds? where seconds > 0:
            let end = at.addingTimeInterval(TimeInterval(seconds))
            next.restStart = at
            next.restEnd = end
            next.restLabel = state.afterRestLabel
            next.restOver = state.afterRestOver
            next.restMinus = state.afterRestMinus
            next.restPlus = state.afterRestPlus
            next.restSkip = state.afterRestSkip
            if let title = state.afterRestTitle, let subtitle = state.afterRestSubtitle {
                notification = RestNotification(
                    title: title, body: state.afterRestBody, subtitle: subtitle, exerciseId: exerciseId, at: end
                )
            }
        default:
            next.restStart = nil
            next.restEnd = nil
            next.restLabel = nil
            next.restOver = nil
            next.restMinus = nil
            next.restPlus = nil
            next.restSkip = nil
        }
        next.doneSetId = nil
        next.doneExerciseId = nil
        next.doneLabel = nil
        next.afterExercise = nil
        next.afterNext = nil
        next.afterRest = nil
        next.afterRestLabel = nil
        next.afterRestOver = nil
        next.afterRestMinus = nil
        next.afterRestPlus = nil
        next.afterRestSkip = nil
        next.afterRestTitle = nil
        next.afterRestBody = nil
        next.afterRestSubtitle = nil
        return (next, notification)
    }

    /// Schedules [notification] under Dart's id, as flutter_local_notifications
    /// would have: the same identifier, the payload where the plugin keeps it,
    /// so a tap on it reaches the app's own router.
    private static func schedule(_ notification: RestNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.subtitle = notification.subtitle
        if let body = notification.body { content.body = body }
        content.sound = .default
        content.userInfo = ["payload": notification.exerciseId]
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: max(notification.at, Date().addingTimeInterval(1))
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restNotification])
        try? await center.add(UNNotificationRequest(identifier: restNotification, content: content, trigger: trigger))
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
struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark Set Done"
    static let isDiscoverable = false

    @Parameter(title: "Workout")
    var workoutId: String

    @Parameter(title: "Set")
    var setId: String

    init() {
        workoutId = ""
        setId = ""
    }

    init(workoutId: String, setId: String) {
        self.workoutId = workoutId
        self.setId = setId
    }

    func perform() async throws -> some IntentResult {
        await OngoingWorkoutIntents.complete(workoutId: workoutId, setId: setId)
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
