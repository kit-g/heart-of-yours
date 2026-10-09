import XCTest

@testable import Runner

/// A set logged by voice (#287): the tick handed to Dart, and what Siri says.
@available(iOS 17, *)
final class LogSetVoiceTests: XCTestCase {
    private func set(
        weighted: Bool = true, counted: Bool = true, weight: Double? = 100, reps: Int? = 5, completable: Bool = true
    ) -> LogSetVoice.NextSet {
        var map: [String: Any] = [
            "workoutId": "w1", "setId": "s1", "exerciseName": "Bench Press",
            "weighted": weighted, "counted": counted, "unit": "kg", "completable": completable,
        ]
        if let weight { map["weight"] = weight }
        if let reps { map["reps"] = reps }
        return LogSetVoice.NextSet(map)!
    }

    func testTheValuesSaidGoWithTheTick() {
        let (command, outcome) = LogSetVoice.plan(set(), weight: 102.5, reps: 3)

        XCTAssertEqual(command?["action"] as? String, "complete")
        XCTAssertEqual(command?["setId"] as? String, "s1")
        XCTAssertEqual(command?["weight"] as? Double, 102.5)
        XCTAssertEqual(command?["reps"] as? Int, 3)
        XCTAssertEqual(outcome, .logged(description: "102.5 kg × 3, Bench Press"))
    }

    func testNothingSaidLogsTheSetsOwnValues() {
        let (command, outcome) = LogSetVoice.plan(set(), weight: nil, reps: nil)
        XCTAssertEqual(command?["weight"] as? Double, 100)
        XCTAssertEqual(command?["reps"] as? Int, 5)
        XCTAssertEqual(outcome, .logged(description: "100 kg × 5, Bench Press"))
    }

    func testASetThatTakesNoWeightHearsNone() {
        let (command, outcome) = LogSetVoice.plan(set(weighted: false, weight: nil, reps: 12), weight: 50, reps: nil)
        XCTAssertNil(command?["weight"])
        XCTAssertEqual(command?["reps"] as? Int, 12)
        XCTAssertEqual(outcome, .logged(description: "× 12, Bench Press"))
    }

    func testAnEmptySetNeedsTheValuesSaid() {
        let empty = set(weight: nil, reps: nil, completable: false)
        XCTAssertEqual(LogSetVoice.plan(empty, weight: nil, reps: nil).outcome, .needsValues)
        XCTAssertNil(LogSetVoice.plan(empty, weight: 60, reps: nil).command, "half is not enough")
        let (command, outcome) = LogSetVoice.plan(empty, weight: 60, reps: 8)
        XCTAssertNotNil(command)
        XCTAssertEqual(outcome, .logged(description: "60 kg × 8, Bench Press"))
    }

    func testNoSetIsNoWorkout() {
        XCTAssertEqual(LogSetVoice.plan(nil, weight: 60, reps: 8).outcome, .noWorkout)
    }

    func testSiriAsksForWhatTheSetLacksWeightFirst() {
        let empty = LogSetVoice.NextSet(["workoutId": "w1", "setId": "s1", "exerciseName": "Bench", "weighted": true, "counted": true, "unit": "kg", "completable": false])
        XCTAssertEqual(LogSetVoice.missing(empty, weight: nil, reps: nil), .weight)
        XCTAssertEqual(LogSetVoice.missing(empty, weight: 100, reps: nil), .reps)
        XCTAssertNil(LogSetVoice.missing(empty, weight: 100, reps: 5))
        let planned = LogSetVoice.NextSet(["workoutId": "w1", "setId": "s1", "exerciseName": "Bench", "weighted": true, "counted": true, "unit": "kg", "weight": 100.0, "reps": 5, "completable": true])
        XCTAssertNil(LogSetVoice.missing(planned, weight: nil, reps: nil), "a set that can be ticked as it stands asks for nothing")
        XCTAssertNil(LogSetVoice.missing(nil, weight: nil, reps: nil), "nothing to log is said, not asked")
    }
}
