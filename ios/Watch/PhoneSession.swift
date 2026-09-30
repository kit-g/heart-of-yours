import Combine
import WatchConnectivity
import WidgetKit

/// The watch's end of the link to the phone: holds the last [WatchState] the
/// phone sent (#182), and carries what the user does here back to it (#183).
///
/// Opening is both the opt-in's yes (`docs/opt-in.md`) and a request for the
/// current state. The yes goes as user info — queued by the system and
/// delivered even if the phone app isn't running — and once only; the request
/// goes as a message, which only means anything while the phone can answer.
///
/// Commands are requests, never edits: nothing here changes the state. It
/// changes when the phone sends the state that results, and until then the
/// command is [pending].
@MainActor
final class PhoneSession: NSObject, ObservableObject {
    @Published private(set) var state: WatchState = .awaiting

    /// Whether the phone can hear a command right now. Commands are not queued
    /// on the watch: while the phone is out of reach, the controls are not
    /// offered at all.
    @Published private(set) var reachable = false

    /// A command was sent and the phone has not answered it with a state yet.
    @Published private(set) var pending = false

    private let announcedKey = "phone.openedAnnounced"

    /// How long a command may go unanswered before the controls come back —
    /// the phone may have dropped it (a stale set, a finished workout) without
    /// anything new to say.
    private let patience: Duration = .seconds(5)

    enum Command {
        case complete(workoutId: String, setId: String, weight: Double?, reps: Int?)
        case skipRest(workoutId: String)
        case adjustRest(workoutId: String, seconds: Int)

        var message: [String: Any] {
            switch self {
            case let .complete(workoutId, setId, weight, reps):
                var message: [String: Any] = ["event": "command", "action": "complete", "workoutId": workoutId, "setId": setId]
                message["weight"] = weight
                message["reps"] = reps
                return message
            case let .skipRest(workoutId):
                return ["event": "command", "action": "skipRest", "workoutId": workoutId]
            case let .adjustRest(workoutId, seconds):
                return ["event": "command", "action": "adjustRest", "workoutId": workoutId, "seconds": seconds]
            }
        }
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ command: Command) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable, !pending else { return }
        pending = true
        sent += 1
        let this = sent
        session.sendMessage(command.message, replyHandler: { _ in }, errorHandler: { _ in
            Task { @MainActor in if self.sent == this { self.pending = false } }
        })
        Task {
            try? await Task.sleep(for: patience)
            if sent == this { pending = false }
        }
    }

    /// Counts commands, so a timeout or an error only clears its own.
    private var sent = 0

    /// The phone finished a workout (#184): the workout id, and when it ended.
    var onFinish: ((String, Date) -> Void)?

    private func apply(_ payload: [String: Any]) {
        if payload["event"] as? String == "finish",
           let workoutId = payload["workoutId"] as? String,
           let end = payload["end"] as? NSNumber {
            return onFinish?(workoutId, Date(timeIntervalSince1970: end.doubleValue / 1000)) ?? ()
        }
        guard let state = WatchState(payload) else { return }
        // any state answers a pending command, even one identical to the last
        pending = false
        if state != self.state {
            self.state = state
            updateComplication(state)
        }
    }

    /// Hands the complication (#186) what it draws, and redraws it only when
    /// that changed: the system budgets reloads, and a state that differs only
    /// in what the complication does not show is not worth one.
    private func updateComplication(_ state: WatchState) {
        let snapshot: ComplicationSnapshot? = switch state {
        case .workout(let workout):
            .init(
                exercise: workout.exercise,
                next: workout.next,
                restStart: workout.rest?.window.lowerBound,
                restEnd: workout.rest?.window.upperBound,
                restLabel: workout.rest?.label
            )
        case .idle, .off, .awaiting:
            nil
        }
        if ComplicationSnapshot.write(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func announce(_ session: WCSession) {
        let opened = ["event": "opened"]
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: announcedKey) {
            session.transferUserInfo(opened)
            defaults.set(true, forKey: announcedKey)
        }
        if session.isReachable {
            session.sendMessage(opened, replyHandler: nil, errorHandler: nil)
        }
    }
}

extension PhoneSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            // what the phone last said, even if it said it while this app was closed
            self.apply(context)
            self.reachable = reachable
            self.announce(session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    /// The finish, queued by the phone so it arrives even out of reach.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.apply(userInfo) }
    }

    /// The phone came within reach: ask again, in case what the context holds
    /// is from before the last change.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.reachable = reachable }
        guard reachable else { return }
        session.sendMessage(["event": "opened"], replyHandler: nil, errorHandler: nil)
    }
}
