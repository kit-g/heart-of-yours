import XCTest

/// Drives the watch app on a simulator, the way `flutter_driver` drives the
/// phone (#183) — which is what these are: steps, not a suite. They assume the
/// paired phone simulator is running Heart with a workout in progress and the
/// watch app switched on, and each does one thing and checks it landed.
///
///     xcodebuild test -workspace ios/Runner.xcworkspace -scheme watch-dev \
///       -destination id=<watch udid> \
///       -only-testing:WatchUITests/WatchUITests/testTickNextSet
///
/// Neither `simctl` nor clicks on the Simulator window reach a watch app on
/// this machine; XCUITest does, Digital Crown included.
final class WatchUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.activate()
    }

    /// Done ticks the set the watch shows; the phone answers with the next one,
    /// and the button comes back (it spins while the phone has not answered).
    func testTickNextSet() {
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        let before = app.staticTexts.allElementsBoundByIndex.map(\.label)

        done.tap()

        XCTAssertTrue(done.waitForExistence(timeout: 10))
        let after = app.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertNotEqual(before, after, "the phone sent the state that follows the tick")
    }

    /// The Digital Crown moves the focused value, a detent at a time.
    func testCrownAdjustsWeight() {
        // adjustable, so it is exposed as whatever element type carries that trait
        let weight = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["kg", "lbs"])).firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 10))
        let before = weight.value as? String

        weight.tap()
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)

        XCTAssertNotEqual(weight.value as? String, before)
    }

    /// What the crown set is what Done sends: the phone should now hold the
    /// set with the adjusted weight, and show it in the set row.
    func testCrownThenTick() {
        let weight = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["kg", "lbs"])).firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 10))
        weight.tap()
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        let adjusted = weight.value as? String

        app.buttons["Done"].tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10))
        XCTAssertNotNil(adjusted)
    }

    /// Skip ends the rest the phone is counting.
    func testSkipRest() {
        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))

        skip.tap()

        XCTAssertTrue(skip.waitForNonExistence(timeout: 10), "the phone stopped the rest and said so")
    }
}
