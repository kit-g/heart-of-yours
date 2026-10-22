import XCTest
@testable import Watch

/// What the phone sends, as `test/watch_fixtures_test.dart` writes it to
/// `test/fixtures/watch/` (#466) — the same files the Wear OS app's tests read
/// (android/wear/src/test). A change on the phone that this watch cannot read
/// fails here. Read from the checkout: the simulator sees the host's files.
final class FixturesTests: XCTestCase {
    private func fixture(_ name: String) throws -> Any {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // WatchTests
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // the checkout
            .appendingPathComponent("test/fixtures/watch/\(name)")
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    }

    private func workout(_ name: String) throws -> WatchState.Workout {
        let payload = try XCTUnwrap(fixture(name) as? [String: Any])
        guard case .workout(let workout) = WatchState(payload) else {
            XCTFail("\(name) did not read as a workout")
            throw XCTSkip()
        }
        return workout
    }

    func testARestingWorkoutReadsWhole() throws {
        let workout = try workout("workout_resting.json")
        XCTAssertEqual(workout.workoutId, "w1")
        XCTAssertEqual(workout.rest.map { $0.window.upperBound.timeIntervalSince($0.window.lowerBound) }, 90)
        XCTAssertEqual(workout.set?.setId, "b3")
        XCTAssertEqual(workout.set?.weight, 62.5)
        XCTAssertEqual(workout.exercises.map(\.id), ["bench", "pullup"])
        XCTAssertEqual(workout.exercises.first?.sets.first?.mark, "W")
        XCTAssertNil(workout.exercises.last?.unit, "a reps-only exercise has no unit")
        XCTAssertEqual(workout.controls?.reps, "Reps")
        XCTAssertEqual(workout.pauses.count, 1)
        XCTAssertEqual(workout.clock, workout.startedAt.addingTimeInterval(30))
    }

    func testAPausedWorkoutWithEverySetTickedHasNothingUpNext() throws {
        let workout = try workout("workout_paused_done.json")
        XCTAssertNil(workout.set)
        XCTAssertNil(workout.rest)
        XCTAssertNotNil(workout.pausedAt)
        XCTAssertEqual(workout.next, "All done")
    }

    func testIdleAndOff() throws {
        XCTAssertEqual(WatchState(try XCTUnwrap(fixture("idle.json") as? [String: Any])), .idle("Start a workout on your phone"))
        XCTAssertEqual(WatchState(try XCTUnwrap(fixture("off.json") as? [String: Any])), .off("Turned off in Heart on your phone"))
    }

    func testTheCommandsAWatchSendsAreTheOnesItReadsBack() throws {
        let commands = try XCTUnwrap(fixture("commands.json") as? [[String: Any]])
        for sent in commands {
            let command = try XCTUnwrap(PhoneSession.Command(message: sent), "\(sent["action"] ?? "") reads")
            // what this watch writes for it is the same command, key for key —
            // less the id and the time, which `send` stamps
            XCTAssertEqual(Set(command.message.keys).union(["id", "at"]), Set(sent.keys))
        }
    }
}
