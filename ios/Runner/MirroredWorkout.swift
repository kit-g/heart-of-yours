import HealthKit
import os

/// The phone's side of the watch's workout session (#184).
///
/// The watch mirrors its session here. Holding the mirrored session is the
/// whole job: while one is live, iOS keeps Heart running in the background, so
/// a tick from the wrist finds Dart awake rather than waiting on a background
/// launch. Nothing is read from it — the heart rate and energy the watch
/// measures stay on the watch and in Health, and never reach Dart.
///
/// Registered at launch: the system relaunches the app to hand over a session
/// started while it was not running, and delivers it to whatever handler is
/// set by then.
@available(iOS 17.0, *)
final class MirroredWorkout: NSObject {
    static let shared = MirroredWorkout()

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private let log = Logger(subsystem: "me.heart-of", category: "Watch")

    func listen() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        store.workoutSessionMirroringStartHandler = { [weak self] session in
            DispatchQueue.main.async {
                self?.session = session
                session.delegate = self
            }
        }
    }
}

@available(iOS 17.0, *)
extension MirroredWorkout: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended || toState == .stopped else { return }
        DispatchQueue.main.async { self.session = nil }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        log.error("Mirrored workout session failed: \(error.localizedDescription, privacy: .public)")
        DispatchQueue.main.async { self.session = nil }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?) {
        DispatchQueue.main.async { self.session = nil }
    }
}
