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
/// Commands are requests, never edits. The watch shows each one applied to the
/// phone's last state at once ([WatchState.applying]), and the phone's answer
/// replaces that: the phone is still the only writer. In reach, a command goes
/// as a message. Out of reach (#206) — the phone in a locker — or when a
/// message fails, it goes as user info, which the system holds and delivers in
/// order once the phone is back.
///
/// Reach is not to be trusted: a phone walked out of range still reads as
/// reachable for a while, and a message sent then fails only when it times
/// out. Applying at once is what keeps the watch from standing still meanwhile.
@MainActor
final class PhoneSession: NSObject, ObservableObject {
    /// What to show: the phone's last state, with [queued] applied on top.
    @Published private(set) var state: WatchState = .awaiting

    /// What the phone last said.
    private var phoneState: WatchState = .awaiting

    /// Commands the phone has not answered, oldest first.
    @Published private(set) var queued: [Queued] = []

    struct Queued {
        let id: String
        let command: Command
        let at: Date
        /// Gone as user info — waiting for the phone to be back — rather than
        /// as a message in flight.
        var transferred = false
        /// Handed to the phone, which has not sent a state since.
        var delivered = false
    }

    /// The sets a transferred command is about: shown as not yet on the phone.
    var unsynced: Set<String> {
        Set(queued.filter(\.transferred).compactMap(\.command.setId))
    }

    /// Something waits for the phone to be back.
    var waiting: Bool {
        queued.contains(where: \.transferred)
    }

    /// Whether the phone can hear a message right now. Out of reach, commands
    /// queue instead.
    @Published private(set) var reachable = false

    private let announcedKey = "phone.openedAnnounced"

    enum Command: Equatable {
        case complete(workoutId: String, setId: String, weight: Double?, reps: Int?)
        case skipRest(workoutId: String)
        case adjustRest(workoutId: String, seconds: Int)
        case finish(workoutId: String)
        /// New values for a set already done; it stays ticked.
        case edit(workoutId: String, setId: String, weight: Double?, reps: Int?)
        /// A set ticked by mistake.
        case untick(workoutId: String, setId: String)

        var message: [String: Any] {
            switch self {
            case let .complete(workoutId, setId, weight, reps):
                var message: [String: Any] = ["event": "command", "action": "complete", "workoutId": workoutId, "setId": setId]
                message["weight"] = weight
                message["reps"] = reps
                return message
            case let .edit(workoutId, setId, weight, reps):
                var message: [String: Any] = ["event": "command", "action": "edit", "workoutId": workoutId, "setId": setId]
                message["weight"] = weight
                message["reps"] = reps
                return message
            case let .untick(workoutId, setId):
                return ["event": "command", "action": "untick", "workoutId": workoutId, "setId": setId]
            case let .skipRest(workoutId):
                return ["event": "command", "action": "skipRest", "workoutId": workoutId]
            case let .adjustRest(workoutId, seconds):
                return ["event": "command", "action": "adjustRest", "workoutId": workoutId, "seconds": seconds]
            case let .finish(workoutId):
                return ["event": "command", "action": "finish", "workoutId": workoutId]
            }
        }

        var workoutId: String {
            switch self {
            case let .complete(workoutId, _, _, _), let .edit(workoutId, _, _, _), let .untick(workoutId, _),
                 let .skipRest(workoutId), let .adjustRest(workoutId, _), let .finish(workoutId):
                workoutId
            }
        }

        var setId: String? {
            switch self {
            case let .complete(_, setId, _, _), let .edit(_, setId, _, _), let .untick(_, setId): setId
            case .skipRest, .adjustRest, .finish: nil
            }
        }

        /// Read back from a queued transfer, after a relaunch.
        init?(message: [String: Any]) {
            let weight = (message["weight"] as? NSNumber)?.doubleValue
            let reps = (message["reps"] as? NSNumber)?.intValue
            guard let workoutId = message["workoutId"] as? String else { return nil }
            switch (message["action"] as? String, message["setId"] as? String) {
            case let ("complete", setId?): self = .complete(workoutId: workoutId, setId: setId, weight: weight, reps: reps)
            case let ("edit", setId?): self = .edit(workoutId: workoutId, setId: setId, weight: weight, reps: reps)
            case let ("untick", setId?): self = .untick(workoutId: workoutId, setId: setId)
            case ("skipRest", _): self = .skipRest(workoutId: workoutId)
            case ("finish", _): self = .finish(workoutId: workoutId)
            case ("adjustRest", _):
                guard let seconds = (message["seconds"] as? NSNumber)?.intValue else { return nil }
                self = .adjustRest(workoutId: workoutId, seconds: seconds)
            default: return nil
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
        guard session.activationState == .activated else { return }
        let at = Date()
        let id = UUID().uuidString
        var message = command.message
        // when it happened, which is not when a queued one arrives
        message["at"] = (at.timeIntervalSince1970 * 1000).rounded()
        message["id"] = id
        queued.append(.init(id: id, command: command, at: at))

        // while anything waits for the phone, this waits behind it: a message
        // would overtake the queue, and the phone would apply them out of order
        guard session.isReachable, !waiting else {
            return transfer(id, message: message)
        }
        session.sendMessage(message, replyHandler: { _ in
            Task { @MainActor in self.delivered(id) }
        }, errorHandler: { _ in
            // never reached the phone — the reach went as it was sent
            Task { @MainActor in self.transfer(id, message: message) }
        })
        show()
    }

    /// Hands [id] to the system to deliver once the phone is back.
    private func transfer(_ id: String, message: [String: Any]) {
        guard let index = queued.firstIndex(where: { $0.id == id }) else { return }
        WCSession.default.transferUserInfo(message)
        queued[index].transferred = true
        // the workout ends here and now, measured, whenever the phone hears it
        if case let .finish(workoutId) = queued[index].command {
            onFinish?(workoutId, queued[index].at)
        }
        show()
    }

    /// The phone's state with what it has not answered applied, if that changed
    /// what is shown. A Finish counts only once it is queued: in reach, the
    /// phone may still refuse it (a set added there since), and the workout
    /// session must not be told the workout is over before the phone agrees.
    private func show() {
        let shown = queued
            .filter { entry in
                if case .finish = entry.command { return entry.transferred }
                return true
            }
            .reduce(phoneState) { $0.applying($1.command, at: $1.at) }
        if shown != state {
            state = shown
            updateComplication(shown)
        }
    }

    /// What the system still holds for the phone, after a relaunch: the queue
    /// outlives the app, the list of it does not.
    private func restoreQueue(_ session: WCSession) {
        queued = session.outstandingUserInfoTransfers.compactMap { transfer in
            let info = transfer.userInfo
            guard let id = info["id"] as? String, let command = Command(message: info) else { return nil }
            let at = (info["at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) } ?? .now
            return Queued(id: id, command: command, at: at, transferred: true)
        }
    }

    /// The phone has a queued command: it counts as answered at the next
    /// state the phone sends.
    fileprivate func delivered(_ id: String) {
        guard let index = queued.firstIndex(where: { $0.id == id }) else { return }
        queued[index].delivered = true
    }

    /// The phone finished a workout (#184): the workout id, and when it ended.
    var onFinish: ((String, Date) -> Void)?

    private func apply(_ payload: [String: Any]) {
        if payload["event"] as? String == "finish",
           let workoutId = payload["workoutId"] as? String,
           let end = payload["end"] as? NSNumber {
            return onFinish?(workoutId, Date(timeIntervalSince1970: end.doubleValue / 1000)) ?? ()
        }
        guard let state = WatchState(payload) else { return }
        phoneState = state
        // what the phone has heard is in what it sent; the rest still applies
        queued.removeAll(where: \.delivered)
        show()
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
        announceQueue(session)
    }

    /// Back in reach with a queue: tell the phone now. The queue itself goes
    /// when the system gets to it, seconds later — longer after the phone has
    /// restarted — and without this the phone sits there saying nothing (#206).
    private func announceQueue(_ session: WCSession) {
        guard waiting, session.isReachable else { return }
        session.sendMessage(["event": "catchingUp"], replyHandler: nil, errorHandler: nil)
    }
}

extension PhoneSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            self.restoreQueue(session)
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

    /// A queued command reached the phone — or failed to, and goes again.
    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        let info = userInfoTransfer.userInfo
        guard let id = info["id"] as? String else { return }
        if error != nil {
            session.transferUserInfo(info)
            return
        }
        Task { @MainActor in self.delivered(id) }
    }

    /// The phone came within reach: ask again, in case what the context holds
    /// is from before the last change.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.reachable = reachable
            guard reachable else { return }
            session.sendMessage(["event": "opened"], replyHandler: nil, errorHandler: nil)
            self.announceQueue(session)
        }
    }
}
