import XCTest

@testable import Runner

/// The training widget (#161): what Dart publishes, kept for the widget, and
/// the bars the widget draws from it.
final class TrainingSnapshotTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "TrainingSnapshotTests"

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    /// Noon on [day] in October 2026; the 12th is a Monday.
    private func october(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
    }

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testReadsWhatDartSends() {
        let snapshot = TrainingSnapshot(map: [
            "version": 1,
            "unit": "imperial",
            "accent": 0xFF1F4EC8,
            "accentDark": 0xFF93ADFF,
            "days": ["2026-10-11": [1234.5, 1, 3600, 12, 96]],
        ])

        XCTAssertEqual(snapshot?.unit, .imperial)
        XCTAssertEqual(snapshot?.accent, 0xFF1F4EC8)
        XCTAssertEqual(snapshot?.days["2026-10-11"], [1234.5, 1, 3600, 12, 96])
    }

    func testNothingOrNonsenseIsNobodysTraining() {
        XCTAssertNil(TrainingSnapshot(map: nil))
        XCTAssertNil(TrainingSnapshot(map: ["unit": "furlongs", "accent": 0, "accentDark": 0, "days": [:]]))
    }

    func testWritesOnlyWhatChanged() {
        let snapshot = TrainingSnapshot(unit: .metric, accent: 1, accentDark: 2, days: ["2026-10-11": [100, 1, 60, 1, 5]])

        XCTAssertTrue(TrainingSnapshot.write(snapshot, to: defaults))
        XCTAssertFalse(TrainingSnapshot.write(snapshot, to: defaults))
        XCTAssertEqual(TrainingSnapshot.read(from: defaults), snapshot)

        XCTAssertTrue(TrainingSnapshot.write(nil, to: defaults))
        XCTAssertNil(TrainingSnapshot.read(from: defaults))
    }

    func testAWeekIsSevenDaysEndingToday() {
        let snapshot = TrainingSnapshot(unit: .metric, accent: 0, accentDark: 0, days: [
            "2026-10-05": [999, 1, 0, 0, 0],
            "2026-10-06": [100, 1, 0, 0, 0],
            "2026-10-12": [250, 2, 0, 0, 0],
        ])

        let bars = snapshot.bars(.volume, .week, now: october(12), calendar: calendar)

        XCTAssertEqual(bars.map(\.value), [100, 0, 0, 0, 0, 0, 250])
        XCTAssertEqual(bars.first?.start, calendar.startOfDay(for: october(6)))
        XCTAssertEqual(snapshot.bars(.workouts, .week, now: october(12), calendar: calendar).last?.value, 2)
    }

    func testAQuarterIsThirteenWeeksFromMonday() {
        let snapshot = TrainingSnapshot(unit: .metric, accent: 0, accentDark: 0, days: [
            // this week: Monday and Sunday to come
            "2026-10-12": [0, 1, 0, 0, 0],
            // last week, Monday to Sunday
            "2026-10-05": [0, 1, 0, 0, 0],
            "2026-10-11": [0, 1, 0, 0, 0],
            // the first week shown starts on Monday 20 July
            "2026-07-20": [0, 1, 0, 0, 0],
            "2026-07-19": [0, 1, 0, 0, 0],
        ])

        // a Wednesday: the week still starts on the Monday
        let bars = snapshot.bars(.workouts, .quarter, now: october(14), calendar: calendar)

        XCTAssertEqual(bars.count, 13)
        XCTAssertEqual(bars.first?.start, calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!))
        XCTAssertEqual(bars.first?.value, 1)
        XCTAssertEqual(bars.suffix(2).map(\.value), [2, 1])
        XCTAssertEqual(bars.map(\.value).reduce(0, +), 4)
    }

    func testAMissingTotalCountsAsNothing() {
        let snapshot = TrainingSnapshot(unit: .metric, accent: 0, accentDark: 0, days: ["2026-10-12": [10]])

        XCTAssertEqual(snapshot.bars(.reps, .week, now: october(12), calendar: calendar).last?.value, 0)
    }
}
