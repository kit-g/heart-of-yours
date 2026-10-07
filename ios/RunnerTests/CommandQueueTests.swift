import XCTest

@testable import Runner

/// The queue a second actor's commands wait in while no Dart is listening
/// (#183, #141): kept in order, taken once.
final class CommandQueueTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "CommandQueueTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testKeepsInOrderAndTakesOnce() {
        let queue = CommandQueue(key: "test.pending", defaults: defaults)
        queue.keep(["action": "skipRest", "workoutId": "w1"])
        queue.keep(["action": "adjustRest", "workoutId": "w1", "seconds": 10])

        let taken = queue.take()

        XCTAssertEqual(taken.count, 2)
        XCTAssertEqual(taken[0]["action"] as? String, "skipRest")
        XCTAssertEqual(taken[1]["action"] as? String, "adjustRest")
        XCTAssertEqual(taken[1]["seconds"] as? Int, 10)
        XCTAssertEqual(queue.take().count, 0, "asking clears it")
    }

    func testEmptyWhenNothingWasKept() {
        XCTAssertEqual(CommandQueue(key: "test.empty", defaults: defaults).take().count, 0)
    }

    func testQueuesAreKeptApart() {
        let watch = CommandQueue(key: "watch.pendingCommands", defaults: defaults)
        let lockScreen = CommandQueue(key: "ongoingWorkout.pendingCommands", defaults: defaults)
        watch.keep(["action": "complete", "workoutId": "w1", "setId": "s1"])

        XCTAssertEqual(lockScreen.take().count, 0)
        XCTAssertEqual(watch.take().count, 1)
    }
}
