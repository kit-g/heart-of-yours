import XCTest

@testable import Runner

/// The rest timer by voice (#98): what each command does to the app's own
/// store of the rest — the one the app restores on launch — and what it
/// answers.
@available(iOS 17, *)
final class RestVoiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "RestVoiceTests"
    private let now = Date(timeIntervalSince1970: 1_791_400_000)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func published(seconds: Int? = 90) {
        var rest: [String: Any] = [
            "workoutId": "w1",
            "exerciseId": "x1",
            "title": "Rest complete!",
            "body": "60 kg x 5",
            "subtitle": "Bench Press is next",
        ]
        if let seconds { rest["seconds"] = seconds }
        defaults.set(rest, forKey: ShortcutsChannel.restKey)
    }

    func testWithNoWorkoutNothingIsStarted() async {
        let outcome = await RestVoice.start(seconds: nil, defaults: defaults, now: now)
        XCTAssertEqual(outcome, .noWorkout)
        XCTAssertNil(defaults.object(forKey: RestVoice.restEndKey))
    }

    func testStartUsesTheExerciseSettingAndWritesTheAppsStore() async {
        published(seconds: 90)

        let outcome = await RestVoice.start(seconds: nil, defaults: defaults, now: now)

        XCTAssertEqual(outcome, .started(seconds: 90))
        XCTAssertEqual(defaults.string(forKey: RestVoice.restExerciseKey), "x1")
        XCTAssertEqual(defaults.integer(forKey: RestVoice.restTotalKey), 90)
        XCTAssertEqual(RestVoice.runningRest(in: defaults, now: now)?.end, now.addingTimeInterval(90))
    }

    func testALengthSaidWinsOverTheSetting() async {
        published(seconds: 90)
        let outcome = await RestVoice.start(seconds: 120, defaults: defaults, now: now)
        XCTAssertEqual(outcome, .started(seconds: 120))
        XCTAssertEqual(defaults.integer(forKey: RestVoice.restTotalKey), 120)
    }

    func testNoTimerAndNothingSaidIsRefused() async {
        published(seconds: nil)
        let outcome = await RestVoice.start(seconds: nil, defaults: defaults, now: now)
        XCTAssertEqual(outcome, .noTimer)
        XCTAssertNil(defaults.object(forKey: RestVoice.restEndKey))
    }

    func testExtendMovesTheEndAndSaysWhatIsLeft() async {
        published()
        _ = await RestVoice.start(seconds: 60, defaults: defaults, now: now)

        let outcome = await RestVoice.extend(by: 30, defaults: defaults, now: now.addingTimeInterval(10))

        XCTAssertEqual(outcome, .extended(by: 30, left: 80))
        XCTAssertEqual(defaults.integer(forKey: RestVoice.restTotalKey), 90)
    }

    func testExtendAndSkipWithNoRestRunningSaySo() async {
        published()
        let extended = await RestVoice.extend(by: 30, defaults: defaults, now: now)
        XCTAssertEqual(extended, .noRest)
        let skipped = await RestVoice.skip(defaults: defaults, now: now)
        XCTAssertEqual(skipped, .noRest)
        // a rest that ran out is no rest either
        _ = await RestVoice.start(seconds: 60, defaults: defaults, now: now)
        let late = await RestVoice.skip(defaults: defaults, now: now.addingTimeInterval(61))
        XCTAssertEqual(late, .noRest)
    }

    func testSkipClearsTheAppsStore() async {
        published()
        _ = await RestVoice.start(seconds: 60, defaults: defaults, now: now)

        let outcome = await RestVoice.skip(defaults: defaults, now: now)

        XCTAssertEqual(outcome, .skipped)
        XCTAssertNil(defaults.object(forKey: RestVoice.restEndKey))
        XCTAssertNil(defaults.string(forKey: RestVoice.restExerciseKey))
    }

    func testTheClockReadsLikeTheApps() {
        XCTAssertEqual(RestVoice.clock(90), "1:30")
        XCTAssertEqual(RestVoice.clock(5), "0:05")
    }
}

/// Starting a rest on the Live Activity by voice (#98).
@available(iOS 17, *)
final class StartRestTransitionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_400_000)

    func testDrawsTheRestWithTheLabelsTheStateCarries() {
        var state = OngoingWorkoutAttributes.ContentState(
            title: "Leg Day", exercise: "Squat", next: "Next: set 1",
            stopwatchStart: nil, stopwatchLabel: nil, stopwatchPausedAt: nil,
            restStart: nil, restEnd: nil, restLabel: nil, restOver: nil,
            restMinus: nil, restPlus: nil, restSkip: nil,
            accent: 0, accentDark: 0, accentInk: 0, accentInkDark: 0,
            clockStart: now, pausedAt: nil, pausedLabel: "Paused"
        )
        XCTAssertNil(OngoingWorkoutIntents.resting(state, for: 90, at: now), "no labels, no row")

        state.afterRestLabel = "Rest"
        state.afterRestOver = "Rest complete!"
        state.afterRestSkip = "Skip"
        let resting = OngoingWorkoutIntents.resting(state, for: 90, at: now)

        XCTAssertEqual(resting?.restStart, now)
        XCTAssertEqual(resting?.restEnd, now.addingTimeInterval(90))
        XCTAssertEqual(resting?.restLabel, "Rest")
        XCTAssertEqual(resting?.restSkip, "Skip")
    }
}
