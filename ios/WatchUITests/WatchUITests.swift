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
/// this machine; XCUITest does, Digital Crown included. What it cannot reach is
/// Health's permission sheet (#184): a remote view, in no element tree, and a
/// sheet dismissed by relaunching the app counts as declined — after which
/// only erasing the simulator asks again. Tap through that one by hand.
final class WatchUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.activate()
        // every step starts on the set up next; the pager keeps whichever page
        // the last one left it on
        app.swipeRight()
    }

    /// Done ticks the set the watch shows, and the watch moves on to the next
    /// one — with the phone in reach or not (#206).
    func testTickNextSet() {
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        let before = screenText

        done.tap()

        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertNotEqual(before, screenText, "the watch moved on to the set that follows")
    }

    /// Every line on screen but the clocks, which change on their own.
    private var screenText: [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { label in
            !label.allSatisfy { $0.isNumber || $0 == ":" }
        }
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

    /// A swipe from the set up next is the whole workout, one row a set.
    func testOpenWorkoutPage() {
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10))

        app.swipeLeft()

        XCTAssertTrue(firstDoneRow.waitForExistence(timeout: 5), "a set already ticked is listed, with its tick")
    }

    /// Opens a ticked set's editor from the workout page, and leaves it open —
    /// for a look, or a screenshot.
    func testOpenSetEditor() {
        app.swipeLeft()
        let row = firstDoneRow
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.tap()

        XCTAssertTrue(app.buttons["Not done"].waitForExistence(timeout: 5))
    }

    /// A set gone back to loses its tick, and the phone says so.
    func testUntickFromWorkoutPage() {
        app.swipeLeft()
        let row = firstDoneRow
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let label = row.label

        row.tap()
        app.buttons["Not done"].tap()

        let unticked = app.buttons.matching(NSPredicate(format: "label == %@", String(label.dropLast(", Done".count)))).firstMatch
        XCTAssertTrue(unticked.waitForExistence(timeout: 10), "the row came back without its tick")
    }

    /// New reps for a set gone back to: the crown, back, Save — and the row
    /// shows what the phone stored, still ticked.
    func testEditFromWorkoutPage() {
        app.swipeLeft()
        let row = firstDoneRow
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let label = row.label

        row.tap()
        app.buttons["Reps"].tap()
        let reps = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Reps'")).firstMatch
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        reps.tap()
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.3)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Save"].tap()

        let edited = app.buttons.matching(NSPredicate(format: "label ENDSWITH ', Done' AND label != %@", label)).firstMatch
        XCTAssertTrue(edited.waitForExistence(timeout: 10), "the row shows the new reps, still ticked")
    }

    /// A row on the workout page that is ticked: its label ends in the tick's.
    private var firstDoneRow: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH ', Done'")).firstMatch
    }
}
