import XCTest
@testable import Watch

/// What the watch shows on its own while the phone is out of reach (#206):
/// `WatchState.applying`, which has to make the phone's moves the way the phone
/// makes them — above all the set up next, which mirrors `upNextIn` in
/// `lib/core/utils/ongoing_workout.dart`. When one changes, so does the other,
/// and these say which way the phone goes.
final class WatchStateTests: XCTestCase {
    private let now = Date()

    // bench: 3 sets, 90s rest; row: 2 sets, no rest
    private func workout(done: Set<String> = [], upNext: String = "b1") -> WatchState {
        func row(_ id: String, _ number: Int, of total: Int) -> WatchState.Workout.Exercise.Row {
            .init(
                id: id, weight: 60, reps: 5, done: done.contains(id),
                position: "Set \(number) of \(total)", previous: "Last time: \(id)", next: "Next: \(id)"
            )
        }
        let exercises: [WatchState.Workout.Exercise] = [
            .init(id: "bench", name: "Bench", unit: "kg", step: 2.5, weighted: true, counted: true, rest: 90,
                  sets: [row("b1", 1, of: 3), row("b2", 2, of: 3), row("b3", 3, of: 3)]),
            .init(id: "row", name: "Row", unit: "kg", step: 2.5, weighted: true, counted: true, rest: nil,
                  sets: [row("r1", 1, of: 2), row("r2", 2, of: 2)]),
        ]
        var controls = WatchState.Workout.Controls(
            done: "Done", skip: "Skip", add: "+10s", subtract: "-10s", reps: "Reps", unreachable: "Away",
            heartRate: "", bpm: "", energy: "", kcal: "",
            finish: "Finish", finishTitle: "", finishConfirm: "", finishCancel: "",
            save: "Save", notDone: "Not done"
        )
        (controls.restLabel, controls.restOver, controls.allDone, controls.idle) = ("Rest", "Over", "All done", "Idle")
        return .workout(.init(
            workoutId: "w", startedAt: now, title: "Push", exercise: "Bench", next: "", rest: nil,
            accent: .orange,
            set: .init(exerciseId: "bench", setId: upNext, weight: 60, reps: 5, unit: "kg", step: 2.5),
            exercises: exercises, controls: controls, activity: nil
        ))
    }

    private func shown(_ state: WatchState) -> WatchState.Workout {
        guard case .workout(let workout) = state else {
            XCTFail("expected a workout, got \(state)")
            fatalError()
        }
        return workout
    }

    func testATickMovesToTheNextOpenSetInTheSameExercise() {
        let after = shown(workout().applying(.complete(workoutId: "w", setId: "b1", weight: 62.5, reps: 6), at: now))

        XCTAssertEqual(after.set?.setId, "b2")
        XCTAssertEqual(after.set?.position, "Set 2 of 3", "the row's own copy, sent ahead for this")
        XCTAssertEqual(after.set?.previous, "Last time: b2")
        XCTAssertEqual(after.next, "Next: b2", "the complication's line")
        let ticked = after.exercises[0].sets[0]
        XCTAssertEqual([ticked.weight, ticked.reps.map(Double.init)], [62.5, 6], "the values the tick sent")
        XCTAssertTrue(ticked.done)
    }

    func testTheLastSetOfAnExerciseMovesToTheNextExercisesFirstOpenSet() {
        let state = workout(done: ["b1", "b2", "r1"], upNext: "b3")
        let after = shown(state.applying(.complete(workoutId: "w", setId: "b3", weight: nil, reps: nil), at: now))

        XCTAssertEqual(after.set?.setId, "r2", "a later exercise gives its first open set, not its first set")
        XCTAssertEqual(after.exercise, "Row")
    }

    func testNothingOpenAfterwardsWrapsToASetSkippedEarlier() {
        let state = workout(done: ["b2", "b3", "r1"], upNext: "r2")
        let after = shown(state.applying(.complete(workoutId: "w", setId: "r2", weight: nil, reps: nil), at: now))

        XCTAssertEqual(after.set?.setId, "b1")
    }

    func testTheLastOpenSetLeavesNothingUpNext() {
        let state = workout(done: ["b1", "b2", "b3", "r1"], upNext: "r2")
        let after = shown(state.applying(.complete(workoutId: "w", setId: "r2", weight: nil, reps: nil), at: now))

        XCTAssertNil(after.set, "every set ticked: the watch offers Finish")
        XCTAssertEqual(after.exercise, "Row", "it stays on the exercise worked last")
        XCTAssertEqual(after.next, "All done")
    }

    func testATickStartsTheExercisesRest() {
        let after = shown(workout().applying(.complete(workoutId: "w", setId: "b1", weight: nil, reps: nil), at: now))

        XCTAssertEqual(after.rest?.window, now...now.addingTimeInterval(90))
        XCTAssertEqual(after.rest?.label, "Rest")
    }

    func testATickOlderThanItsRestStartsNone() {
        let long = now.addingTimeInterval(-300)
        let after = shown(workout().applying(.complete(workoutId: "w", setId: "b1", weight: nil, reps: nil), at: long))

        XCTAssertNil(after.rest)
    }

    func testASetTickedAlreadyIsNotTickedAgain() {
        let state = workout(done: ["b1"], upNext: "b2")
        XCTAssertEqual(state.applying(.complete(workoutId: "w", setId: "b1", weight: 99, reps: 9), at: now), state)
    }

    func testAnEditKeepsTheTickAndWhatIsUpNext() {
        let state = workout(done: ["b1"], upNext: "b2")
        let after = shown(state.applying(.edit(workoutId: "w", setId: "b1", weight: nil, reps: 8), at: now))

        XCTAssertEqual(after.exercises[0].sets[0].reps, 8)
        XCTAssertEqual(after.exercises[0].sets[0].weight, 60, "what the edit did not send stays")
        XCTAssertTrue(after.exercises[0].sets[0].done)
        XCTAssertEqual(after.set?.setId, "b2")
    }

    func testAnUntickKeepsWhatIsUpNext() {
        let state = workout(done: ["b1"], upNext: "b2")
        let after = shown(state.applying(.untick(workoutId: "w", setId: "b1"), at: now))

        XCTAssertFalse(after.exercises[0].sets[0].done)
        XCTAssertEqual(after.set?.setId, "b2", "as on the phone: up next follows the last tick")
    }

    func testRestIsAdjustedAndSkipped() {
        let resting = shown(workout().applying(.complete(workoutId: "w", setId: "b1", weight: nil, reps: nil), at: now))
        let state = WatchState.workout(resting)

        let longer = shown(state.applying(.adjustRest(workoutId: "w", seconds: 10), at: now))
        XCTAssertEqual(longer.rest?.window.upperBound, now.addingTimeInterval(100))

        let gone = shown(state.applying(.adjustRest(workoutId: "w", seconds: -120), at: now))
        XCTAssertNil(gone.rest, "shortened past now: over")

        XCTAssertNil(shown(state.applying(.skipRest(workoutId: "w"), at: now)).rest)
    }

    func testFinishLeavesTheIdleLine() {
        XCTAssertEqual(workout().applying(.finish(workoutId: "w"), at: now), .idle("Idle"))
    }

    func testACommandAboutAnotherWorkoutChangesNothing() {
        let state = workout()
        XCTAssertEqual(state.applying(.complete(workoutId: "other", setId: "b1", weight: nil, reps: nil), at: now), state)
    }

    func testRowsAndRestAreReadFromWhatThePhoneSends() {
        let state = WatchState([
            "state": "workout", "workoutId": "w", "startedAt": NSNumber(value: 0), "title": "Push",
            "exercise": "Bench", "next": "",
            "exercises": [[
                "id": "bench", "name": "Bench", "unit": "kg", "step": 2.5, "weighted": true, "counted": true,
                "rest": 90,
                "sets": [["id": "b1", "weight": 60, "reps": 5, "done": false,
                          "position": "Set 1 of 1", "previous": "Last time: 60 kg × 5", "next": "Next: set 1"]],
            ]],
        ])

        let exercise = shown(state!).exercises.first
        XCTAssertEqual(exercise?.rest, 90)
        XCTAssertEqual(exercise?.sets.first?.position, "Set 1 of 1")
        XCTAssertEqual(exercise?.sets.first?.previous, "Last time: 60 kg × 5")
        XCTAssertEqual(exercise?.sets.first?.next, "Next: set 1")
    }
}
