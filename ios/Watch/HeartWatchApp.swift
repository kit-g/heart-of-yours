import SwiftUI

/// Heart on the wrist (#175): a remote for the workout the phone is running.
///
/// The phone owns the workout; this app holds nothing of its own but the last
/// state the phone sent (#182). Until then there is nothing to say, and no copy
/// to say it with — every string arrives from Dart, already localised — so the
/// first screen is a picture, not a sentence.
@main
struct HeartWatchApp: App {
    @StateObject private var phone = PhoneSession()
    @StateObject private var session = WorkoutSession()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            PhoneStateView(state: phone.state)
                .environmentObject(phone)
                .environmentObject(session)
                .task {
                    phone.onFinish = { [session] workoutId, end in session.finish(workoutId, end: end) }
                    phone.activate()
                }
                // the workout session starts only with Heart on screen during a
                // workout — see `WorkoutSession` for why never otherwise
                .task(id: SessionTrigger(state: phone.state, active: phase == .active)) {
                    switch phone.state {
                    case .workout(let workout) where phase == .active:
                        await session.start(workout)
                    case .workout:
                        break
                    case .idle, .off, .awaiting:
                        session.workoutEnded()
                    }
                }
                // the rest tap: the watch's while it measures, the phone's otherwise
                .task(id: RestTrigger(end: phone.state.restEnd, measuring: session.measuring)) {
                    session.rest(endingAt: phone.state.restEnd)
                }
                // the session pauses with the workout (#134)
                .task(id: PauseTrigger(paused: phone.state.paused, measuring: session.measuring)) {
                    session.follow(paused: phone.state.paused)
                }
        }
    }
}

/// What decides whether the workout session should run: which workout, and
/// whether Heart is on screen. Not the whole state — a ticked set is no reason
/// to look again.
private struct SessionTrigger: Equatable {
    let workoutId: String?
    let active: Bool

    init(state: WatchState, active: Bool) {
        self.workoutId = switch state {
        case .workout(let workout): workout.workoutId
        default: nil
        }
        self.active = active
    }
}

/// When the current rest ends, and whether the watch is the one to say so.
private struct RestTrigger: Equatable {
    let end: Date?
    let measuring: Bool
}

/// Whether the workout is paused, and whether there is a session to pause.
private struct PauseTrigger: Equatable {
    let paused: Bool
    let measuring: Bool
}

private extension WatchState {
    var restEnd: Date? {
        switch self {
        case .workout(let workout): workout.rest?.window.upperBound
        default: nil
        }
    }

    var paused: Bool {
        switch self {
        case .workout(let workout): workout.pausedAt != nil
        default: false
        }
    }
}

struct PhoneStateView: View {
    let state: WatchState

    var body: some View {
        switch state {
        case .awaiting:
            AwaitingPhone()
        case .workout(let workout):
            WorkoutView(workout: workout)
        case .idle(let message):
            Message(text: message)
        case .off(let message):
            Message(text: message)
        }
    }
}

/// Before the phone has sent anything: the iPhone symbol, which is the whole
/// instruction, and reads in every language.
struct AwaitingPhone: View {
    var body: some View {
        Image(systemName: "iphone")
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(.secondary)
    }
}

/// No workout, or switched off: one line, pointing at the phone.
struct Message: View {
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

#Preview("Awaiting") {
    PhoneStateView(state: .awaiting)
}

#Preview("Idle") {
    PhoneStateView(state: .idle("Start a workout on your iPhone"))
}
