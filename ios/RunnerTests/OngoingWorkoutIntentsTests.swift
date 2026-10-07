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
