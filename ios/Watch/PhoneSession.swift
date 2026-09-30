import Combine
import WatchConnectivity

/// The watch's end of the link to the phone (#182): holds the last
/// [WatchState] the phone sent, and tells the phone when the app opens.
///
/// Opening is both the opt-in's yes (`docs/opt-in.md`) and a request for the
/// current state. The yes goes as user info — queued by the system and
/// delivered even if the phone app isn't running — and once only; the request
/// goes as a message, which only means anything while the phone can answer.
@MainActor
final class PhoneSession: NSObject, ObservableObject {
    @Published private(set) var state: WatchState = .awaiting

    private let announcedKey = "phone.openedAnnounced"

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func apply(_ payload: [String: Any]) {
        if let state = WatchState(payload), state != self.state {
            self.state = state
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
        Task { @MainActor in
            // what the phone last said, even if it said it while this app was closed
            self.apply(context)
            self.announce(session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    /// The phone came within reach: ask again, in case what the context holds
    /// is from before the last change.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        session.sendMessage(["event": "opened"], replyHandler: nil, errorHandler: nil)
    }
}
