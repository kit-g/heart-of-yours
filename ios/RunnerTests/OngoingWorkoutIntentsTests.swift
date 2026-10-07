import XCTest

@testable import Runner

/// The rest buttons on the Live Activity (#141): what each does to the
/// activity's state before the app has heard of it.
@available(iOS 17, *)
final class OngoingWorkoutIntentsTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_400_000)

    private func resting() -> OngoingWorkoutAttributes.ContentState {
        OngoingWorkoutAttributes.ContentState(
            title: "Leg Day",
            exercise: "Squat (Barbell)",
            next: "Next: set 2 · 185 kg x 5",
            stopwatchStart: nil,
            stopwatchLabel: nil,
            stopwatchPausedAt: nil,
            restStart: start,
            restEnd: start.addingTimeInterval(90),
            restLabel: "Rest",
            restOver: "Rest complete!",
            restMinus: "-10s",
            restPlus: "+10s",
            restSkip: "Skip",
            accent: 0xFF00_0000,
            accentDark: 0xFF00_0000,
            accentInk: 0xFFFF_FFFF,
            accentInkDark: 0xFFFF_FFFF,
            clockStart: start,
            pausedAt: nil,
            pausedLabel: "Paused"
        )
    }

    func testTenSecondsOnMovesTheEndAndKeepsTheButtons() {
        let moved = OngoingWorkoutIntents.adjusted(resting(), by: 10)

        XCTAssertEqual(moved?.restEnd, start.addingTimeInterval(100))
        XCTAssertEqual(moved?.restStart, start, "the window's start is where it was")
        XCTAssertEqual(moved?.restPlus, "+10s")
        XCTAssertEqual(moved?.next, "Next: set 2 · 185 kg x 5")
    }

    func testTenSecondsOffMovesTheEndBack() {
        XCTAssertEqual(OngoingWorkoutIntents.adjusted(resting(), by: -10)?.restEnd, start.addingTimeInterval(80))
    }

    func testSkipEndsTheRestAndTakesTheButtonsWithIt() {
        let skipped = OngoingWorkoutIntents.adjusted(resting(), by: nil)

        XCTAssertNotNil(skipped)
        XCTAssertNil(skipped?.rest)
        XCTAssertNil(skipped?.restEnd)
        XCTAssertNil(skipped?.restLabel)
        XCTAssertNil(skipped?.restMinus)
        XCTAssertNil(skipped?.restPlus)
        XCTAssertNil(skipped?.restSkip)
        XCTAssertEqual(skipped?.exercise, "Squat (Barbell)", "the rest of the state stands")
    }

    func testAButtonAfterTheRestEndedIsNothingToDo() {
        var over = resting()
        over.restStart = nil
        over.restEnd = nil

        XCTAssertNil(OngoingWorkoutIntents.adjusted(over, by: 10))
        XCTAssertNil(OngoingWorkoutIntents.adjusted(over, by: nil))
    }
}
/// The Done button (#246): what ticking the set up next does to the state.
@available(iOS 17, *)
final class CompleteSetIntentTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_400_000)

    private func upNext(rest: Int? = 90) -> OngoingWorkoutAttributes.ContentState {
        var state = OngoingWorkoutAttributes.ContentState(
            title: "Leg Day",
            exercise: "Squat (Barbell)",
            next: "Next: set 1 · 185 kg x 5",
            stopwatchStart: nil,
            stopwatchLabel: nil,
            stopwatchPausedAt: nil,
            restStart: nil,
            restEnd: nil,
            restLabel: nil,
            restOver: nil,
            restMinus: nil,
            restPlus: nil,
            restSkip: nil,
            accent: 0xFF00_0000,
            accentDark: 0xFF00_0000,
            accentInk: 0xFFFF_FFFF,
            accentInkDark: 0xFFFF_FFFF,
            clockStart: now,
            pausedAt: nil,
            pausedLabel: "Paused"
        )
        state.doneSetId = "s1"
        state.doneExerciseId = "x1"
        state.doneLabel = "Done"
        state.afterExercise = "Squat (Barbell)"
        state.afterNext = "Next: set 2 · 185 kg x 5"
        state.afterRest = rest
        state.afterRestLabel = "Rest"
        state.afterRestOver = "Rest complete!"
        state.afterRestMinus = "-10s"
        state.afterRestPlus = "+10s"
        state.afterRestSkip = "Skip"
        state.afterRestTitle = "Rest complete!"
        state.afterRestBody = "185 kg x 5"
        state.afterRestSubtitle = "Squat (Barbell) is next"
        return state
    }

    func testTickMovesOnStartsTheRestAndSchedulesItsNotification() {
        let result = OngoingWorkoutIntents.completed(upNext(), setId: "s1", at: now)

        XCTAssertNotNil(result)
        let (state, notification) = result!
        XCTAssertEqual(state.next, "Next: set 2 · 185 kg x 5")
        XCTAssertEqual(state.restStart, now)
        XCTAssertEqual(state.restEnd, now.addingTimeInterval(90))
        XCTAssertEqual(state.restSkip, "Skip", "the rest's own buttons come with it")
        XCTAssertNil(state.doneSetId, "no Done until the app says what is next")
        XCTAssertNil(state.afterNext)
        XCTAssertEqual(
            notification,
            OngoingWorkoutIntents.RestNotification(
                title: "Rest complete!", body: "185 kg x 5", subtitle: "Squat (Barbell) is next",
                exerciseId: "x1", at: now.addingTimeInterval(90)
            )
        )
    }

    func testAnExerciseWithoutARestTimerMovesOnWithNoRest() {
        let (state, notification) = OngoingWorkoutIntents.completed(upNext(rest: nil), setId: "s1", at: now)!

        XCTAssertNil(state.rest)
        XCTAssertNil(notification)
        XCTAssertEqual(state.next, "Next: set 2 · 185 kg x 5")
    }

    func testATickForAnotherSetIsStale() {
        XCTAssertNil(OngoingWorkoutIntents.completed(upNext(), setId: "s2", at: now))
        var nothing = upNext()
        nothing.doneSetId = nil
        XCTAssertNil(OngoingWorkoutIntents.completed(nothing, setId: "s1", at: now))
    }
}
