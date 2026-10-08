import Flutter
import WatchConnectivity
import os

/// The phone's end of the watch app (#175): the `heart/watch` channel that
/// `lib/core/env/watch.dart` speaks to, over WatchConnectivity.
///
/// A pass-through. Dart builds the watch's whole state — finished copy, instants
/// for the clocks — and this forwards it as the session's application context:
/// the latest one wins, and the system delivers it even to a watch app that
/// isn't running. Nothing here reads it, so nothing here needs to change when
/// the watch learns to draw something new.
///
/// The session is activated at launch, not when Dart first asks: the watch app
/// may be what launched this process (a message wakes the phone app in the
/// background), and a message delivered before activation is lost.
final class WatchChannel: NSObject {
    static let shared = WatchChannel()

    private let log = Logger(subsystem: "me.heart-of", category: "Watch")

    /// Set when the watch app was opened with no Dart listening, and cleared
    /// when Dart takes it — so the opt-in's yes survives a phone app that was
    /// not running at the time. Persisted, because a process woken in the
    /// background for the message may be gone before Dart ever starts.
    private let openedKey = "watch.openedUnseen"

    /// Commands from the watch (#183) that no Dart was listening for — the
    /// message woke this process in the background, and the engine had not
    /// started, or was not listening.
    private let queue = CommandQueue(key: "watch.pendingCommands")

    /// The workout the watch is measuring with a workout session (#184), as the
    /// watch reported it. Persisted: the phone app may be relaunched between
    /// the session starting and the finish.
    private let measuringKey = "watch.measuring"

    private var channel: FlutterMethodChannel?

    /// Callers that asked before the session finished activating.
    private var waiting: [() -> Void] = []

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "heart/watch", binaryMessenger: messenger)
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return result(nil) }
            switch call.method {
            case "installed":
                self.whenActive { result(self.session.map { $0.isPaired && $0.isWatchAppInstalled } ?? false) }
            case "takeOpened":
                let defaults = UserDefaults.standard
                result(defaults.bool(forKey: self.openedKey))
                defaults.removeObject(forKey: self.openedKey)
            case "contentPending":
                // watch content the system holds for this app and has not
                // handed over yet: commands queued while the phone was away (#206)
                self.whenActive { result(self.session?.hasContentPending ?? false) }
            case "takeCommands":
                result(self.queue.take())
            case "measures":
                let workoutId = (call.arguments as? [String: Any])?["workoutId"] as? String
                result(workoutId != nil && UserDefaults.standard.string(forKey: self.measuringKey) == workoutId)
            case "finish":
                guard let arguments = call.arguments as? [String: Any],
                      let workoutId = arguments["workoutId"] as? String,
                      let end = arguments["end"] as? NSNumber
                else {
                    return result(FlutterError(code: "bad_arguments", message: "finish needs a workout", details: nil))
                }
                self.whenActive { result(self.finish(workoutId, end: end)) }
            case "send":
                guard let state = call.arguments as? [String: Any] else {
                    return result(FlutterError(code: "bad_arguments", message: "send needs a state", details: nil))
                }
                self.whenActive {
                    self.send(state)
                    result(nil)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func send(_ state: [String: Any]) {
        guard let session, session.isPaired, session.isWatchAppInstalled else { return }
        // the context is deduplicated by content; a send is a real change by
        // construction (Dart compares first), and the stamp keeps a repeat
        // meant for a reinstalled watch app from being dropped as a duplicate
        var context = state
        context["sentAt"] = Date().timeIntervalSince1970
        do {
            try session.updateApplicationContext(context)
        } catch {
            log.error("Watch context update failed: \(error.localizedDescription, privacy: .public)")
        }
        // the context arrives when the system gets to it; a watch on screen
        // right now should not wait for that
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil) { [log] error in
                log.info("Watch message not delivered: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func whenActive(_ run: @escaping () -> Void) {
        DispatchQueue.main.async {
            guard let session = self.session else { return run() }
            switch session.activationState {
            case .activated:
                run()
            case .inactive, .notActivated:
                self.waiting.append(run)
            @unknown default:
                run()
            }
        }
    }

    /// Tells the watch that [workoutId] was finished, if it is the one the watch
    /// is measuring: the watch then saves its workout to Health, and the answer
    /// tells Dart not to write its own. Queued as user info as well as sent, so
    /// a watch out of reach right now still hears it — a finish it never heard
    /// would read as a cancel, and the measurement would be thrown away.
    private func finish(_ workoutId: String, end: NSNumber) -> Bool {
        let defaults = UserDefaults.standard
        guard let session, defaults.string(forKey: measuringKey) == workoutId else { return false }
        defaults.removeObject(forKey: measuringKey)

        let finish: [String: Any] = ["event": "finish", "workoutId": workoutId, "end": end]
        session.transferUserInfo(finish)
        if session.isReachable {
            session.sendMessage(finish, replyHandler: nil, errorHandler: nil)
        }
        return true
    }

    private func received(_ message: [String: Any]) {
        guard let event = message["event"] as? String else { return }
        DispatchQueue.main.async {
            if event == "command" {
                return self.forward(command: message)
            }
            if event == "measuring" {
                UserDefaults.standard.set(message["workoutId"] as? String, forKey: self.measuringKey)
                return
            }
            if event == "opened" {
                // kept until Dart takes it: the channel may not exist yet, or
                // may belong to an engine that is not listening
                UserDefaults.standard.set(true, forKey: self.openedKey)
            }
            self.channel?.invokeMethod(event, arguments: nil)
        }
    }

    /// Hands a command to Dart, or keeps it if nothing there is listening.
    private func forward(command: [String: Any]) {
        guard let channel else { return keep(command) }
        channel.invokeMethod("command", arguments: command) { [weak self] answer in
            if (answer as? Bool) != true { self?.keep(command) }
        }
    }

    private func keep(_ command: [String: Any]) {
        queue.keep(command)
    }
}

extension WatchChannel: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            log.error("Watch session activation failed: \(error.localizedDescription, privacy: .public)")
        }
        DispatchQueue.main.async {
            let waiting = self.waiting
            self.waiting = []
            waiting.forEach { $0() }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Switching to another watch: activate again so the new one is reachable.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.channel?.invokeMethod("changed", arguments: nil)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        received(message)
    }

    /// A command, sent expecting an answer: the answer is only that it arrived.
    /// What it did comes back as the next state, like every other change.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        received(message)
        replyHandler(["received": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        received(userInfo)
    }
}
