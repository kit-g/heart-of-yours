import HealthKit
import os
import WatchConnectivity
import WatchKit

/// The watch's workout session for the workout the phone is running (#184):
/// what makes Apple Watch measure heart rate and energy, keeps this app awake
/// with the wrist down, and saves the workout to Health with what it measured.
///
/// Measuring is Apple's job; Heart only starts and ends it. The readings are
/// shown on the wrist and written to Health by HealthKit itself — they are
/// never sent to the phone app, the server, or anywhere else
/// (`docs/2026-09-05.health-data.md`).
///
/// **When it starts.** Only a watch can run a workout session, and only one at
/// a time: starting Heart's ends any other app's, Apple's own Workout app
/// included. So Heart never starts one on its own behalf — not from the phone,
/// not in the background. It starts when the user has Heart open on the watch
/// during a workout, which is a person choosing Heart for this session. Anyone
/// running Apple's Workout alongside Heart on the phone keeps it.
///
/// **How it ends.** The phone says when the workout was finished, and only then
/// is the workout saved. A workout that ends without that — cancelled on the
/// phone — is discarded, so nothing Heart did not log lands in Health.
@MainActor
final class WorkoutSession: NSObject, ObservableObject {
    /// Beats per minute, as Apple Watch last measured it; nil before the first
    /// reading or with no session.
    @Published private(set) var heartRate: Double?
    /// Active energy since the session began, in kilocalories.
    @Published private(set) var energy: Double?
    /// Whether a session is running — what decides who taps the wrist when a
    /// rest ends.
    @Published private(set) var measuring = false

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private(set) var workoutId: String?

    /// Finishes heard before the idle state that follows them, by workout.
    private var finished: [String: Date] = [:]

    private let log = Logger(subsystem: "me.heart-of", category: "WorkoutSession")

    /// What Heart reads while a session runs; the workout itself is the one
    /// thing it writes.
    private var read: Set<HKObjectType> {
        [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
    }

    /// Starts measuring [workout], asking for Health access first if it has
    /// never been asked here — the watch app's first workout, after the user
    /// already said yes by opening it (`docs/opt-in.md`, rule 2).
    func start(_ workout: WatchState.Workout) async {
        guard HKHealthStore.isHealthDataAvailable(), session == nil, workoutId != workout.workoutId else { return }
        workoutId = workout.workoutId

        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: read)
        } catch {
            log.error("Health authorization failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        // No `authorizationStatus` check here. Read the moment the Health sheet
        // closes, it still answers as before the user chose, so a yes looked
        // like a no: the first workout after allowing Health went unmeasured,
        // and only the next launch started a session. A real no makes the
        // session fail to begin below, which ends in `discard()` — the same
        // "nothing is measured, everything else carries on".
        log.info("Starting a workout session for \(workout.workoutId, privacy: .public)")

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = WorkoutSession.activityType(workout.activity)
        configuration.locationType = WorkoutSession.locationType(workout.activity)
        if configuration.activityType == .swimming {
            configuration.swimmingLocationType = .pool
        }

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            // the session starts now, but the workout started on the phone —
            // the saved workout spans what Heart logged, not when the wrist
            // joined in
            let start = min(workout.startedAt, .now)
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            // not mirrored to the phone: the iPhone app would need the
            // `workout-processing` background mode, which App Store validation
            // refuses for an app that still supports iOS 15. A tick wakes the
            // phone app on its own, and what was logged away queues (#206)
            tellPhone(["event": "measuring", "workoutId": workout.workoutId])
            measuring = true
        } catch {
            log.error("Workout session failed to start: \(error.localizedDescription, privacy: .public)")
            discard()
        }
    }

    /// The phone finished [workoutId] at [end]: save it. Safe to hear twice —
    /// the phone sends it both ways, so it arrives even out of reach.
    func finish(_ workoutId: String, end: Date) {
        guard workoutId == self.workoutId, let session, let builder else {
            finished[workoutId] = end
            return
        }
        finished[workoutId] = nil
        self.session = nil
        self.builder = nil
        self.workoutId = nil
        session.end()
        Task {
            do {
                try await builder.endCollection(at: end)
                _ = try await builder.finishWorkout()
            } catch {
                log.error("Workout could not be saved: \(error.localizedDescription, privacy: .public)")
            }
            clear()
        }
    }

    /// The phone has no workout any more. If it finished this one, the finish
    /// may still be on its way — it is sent before the idle state, but not
    /// always received before it — so the decision waits a moment for it.
    func workoutEnded() {
        guard let workoutId else { return }
        if let end = finished[workoutId] {
            return finish(workoutId, end: end)
        }
        Task {
            try? await Task.sleep(for: .seconds(10))
            guard self.workoutId == workoutId else { return }
            if let end = finished[workoutId] {
                finish(workoutId, end: end)
            } else {
                discard()
            }
        }
    }

    /// The rest the phone is counting ends at [end] (#185); nil for none.
    ///
    /// While a session runs, this app is awake with the wrist down and taps
    /// the wrist itself when the rest is over — and the phone, told the watch
    /// is measuring, does not schedule its own rest notification, which iOS
    /// would forward to the same wrist. Without a session the watch cannot
    /// wake to tap, so it leaves the rest to the phone's notification.
    func rest(endingAt end: Date?) {
        restAlarm?.cancel()
        guard let end, session != nil, end > .now else { return }
        restAlarm = Task {
            try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow))
            guard !Task.isCancelled, self.session != nil else { return }
            WKInterfaceDevice.current().play(.stop)
        }
    }

    private var restAlarm: Task<Void, Never>?

    /// Ends the session without saving anything: cancelled, or never started.
    func discard() {
        session?.end()
        builder?.discardWorkout()
        session = nil
        builder = nil
        workoutId = nil
        clear()
    }

    private func clear() {
        heartRate = nil
        energy = nil
        measuring = false
        restAlarm?.cancel()
    }

    private func tellPhone(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(message)
    }

    /// `WorkoutActivity` names, as the phone sends them, to HealthKit's — the
    /// same resolution `_activityType` in `heart_health` makes for the phone's
    /// own write.
    static func activityType(_ activity: String?) -> HKWorkoutActivityType {
        switch activity {
        case "strength": .traditionalStrengthTraining
        case "crossTraining": .crossTraining
        case "mixedCardio": .mixedCardio
        case "cycling", "cyclingIndoor": .cycling
        case "elliptical": .elliptical
        case "hiking": .hiking
        case "rowing": .rowing
        case "running", "runningTreadmill": .running
        case "skating": .skatingSports
        case "skiing": .downhillSkiing
        case "snowboarding": .snowboarding
        case "swimming": .swimming
        case "walking": .walking
        case "climbing": .climbing
        case "coreTraining": .coreTraining
        case "flexibility": .flexibility
        case "yoga": .yoga
        case "cardioDance": .cardioDance
        case "highIntensity": .highIntensityIntervalTraining
        case "jumpRope": .jumpRope
        default: .other
        }
    }

    /// Outdoors where the activity usually is, so the watch uses GPS for it;
    /// indoors otherwise. A treadmill run and indoor cycling are named apart
    /// for exactly this.
    static func locationType(_ activity: String?) -> HKWorkoutSessionLocationType {
        switch activity {
        case "cycling", "hiking", "running", "walking", "skiing", "snowboarding": .outdoor
        default: .indoor
        }
    }
}

extension WorkoutSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.log.error("Workout session failed: \(error.localizedDescription, privacy: .public)")
            self.discard()
        }
    }
}

extension WorkoutSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRate = workoutBuilder.statistics(for: HKQuantityType(.heartRate))?
            .mostRecentQuantity()?
            .doubleValue(for: .count().unitDivided(by: .minute()))
        let energy = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
        Task { @MainActor in
            if let heartRate { self.heartRate = heartRate }
            if let energy { self.energy = energy }
        }
    }
}
