import XCTest

@testable import Runner

/// Siri and the Shortcuts app driving Heart (#285): the links the intents
/// open the app on, and the templates Dart publishes for them to name.
final class ShortcutsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "ShortcutsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testStartLinksAreDartsVerbs() {
        XCTAssertEqual(ShortcutURL.start().absoluteString, "\(ShortcutURL.scheme)://app/start")
        XCTAssertEqual(
            ShortcutURL.start(template: "78d84f4d-abde-45bc-a592-b85006d33451").absoluteString,
            "\(ShortcutURL.scheme)://app/start?template=78d84f4d-abde-45bc-a592-b85006d33451"
        )
        XCTAssertEqual(ShortcutURL.finish.absoluteString, "\(ShortcutURL.scheme)://app/finish")
    }

    /// `heart` is the dev build's as much as prod's, so a link on it can open
    /// the other one (#388). The scheme is the bundle id, registered by this
    /// build alone.
    func testLinksUseASchemeOnlyThisBuildRegisters() {
        XCTAssertNotEqual(ShortcutURL.scheme, "heart")
        XCTAssertEqual(ShortcutURL.scheme, Bundle.main.bundleIdentifier)
        let types = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertTrue(schemes.contains(ShortcutURL.scheme), "\(schemes)")
        XCTAssertTrue(schemes.contains("heart"), "links already out there still open the app")
    }

    func testTemplateIdsAreEscapedInTheLink() {
        let url = ShortcutURL.start(template: "a b&c")
        XCTAssertEqual(url.scheme, ShortcutURL.scheme)
        XCTAssertEqual(url.host, "app")
        XCTAssertEqual(url.path, "/start")
        let template = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "template" }?.value
        XCTAssertEqual(template, "a b&c")
    }

    @available(iOS 16, *)
    func testTemplatesRoundTripWhatDartPublished() {
        ShortcutsChannel.store(
            [
                ["id": "t1", "name": "Push Day"],
                ["id": "t2", "name": "Leg Day"],
                ["id": 3, "name": "not a template"],
                ["name": "no id"],
            ],
            in: defaults
        )

        let templates = ShortcutsChannel.templates(in: defaults)

        XCTAssertEqual(templates.map(\.id), ["t1", "t2"])
        XCTAssertEqual(templates.map(\.name), ["Push Day", "Leg Day"])
    }

    @available(iOS 16, *)
    func testNothingPublishedIsNoTemplate() {
        XCTAssertEqual(ShortcutsChannel.templates(in: defaults).count, 0)
        ShortcutsChannel.store([], in: defaults)
        XCTAssertEqual(ShortcutsChannel.templates(in: defaults).count, 0)
    }
}

/// The icon's menu (#356): Start a workout, then the templates, as many as
/// the menu shows, and nothing with the feature off.
final class QuickActionsTests: XCTestCase {
    private let templates: [(id: String, name: String)] = [
        ("t1", "Push Day"), ("t2", "Leg Day"), ("t3", "Pull Day"), ("t4", "Arms"),
    ]

    func testOffIsNoItems() {
        XCTAssertTrue(QuickActions.items(enabled: false, templates: templates).isEmpty)
    }

    func testStartHeadsTheTemplatesUpToTheMenusRoom() {
        let items = QuickActions.items(enabled: true, templates: templates)

        XCTAssertEqual(items.count, QuickActions.room)
        XCTAssertEqual(items.dropFirst().map(\.localizedTitle), ["Push Day", "Leg Day", "Pull Day"])
        XCTAssertEqual(
            items.compactMap(QuickActions.link(of:)).map(\.absoluteString),
            [
                "\(ShortcutURL.scheme)://app/start",
                "\(ShortcutURL.scheme)://app/start?template=t1",
                "\(ShortcutURL.scheme)://app/start?template=t2",
                "\(ShortcutURL.scheme)://app/start?template=t3",
            ]
        )
    }

    func testNoTemplatesIsStartAlone() {
        let items = QuickActions.items(enabled: true, templates: [])

        XCTAssertEqual(items.compactMap(QuickActions.link(of:)), [ShortcutURL.start()])
    }

    func testAnItemThisBuildDidNotMakeOpensNothing() {
        let foreign = UIApplicationShortcutItem(type: "elsewhere", localizedTitle: "Elsewhere")

        XCTAssertNil(QuickActions.link(of: foreign))
    }
}

/// "Not today" from outside the app (#445): the moment is kept for Dart, the
/// day is marked at once, and nothing is offered while nothing is published.
final class NotTodayOutsideTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "NotTodayOutsideTests"
    private var calendar = Calendar(identifier: .gregorian)
    private let words = NotTodaySnapshot(label: "Not today", done: "Today is set aside", day: nil)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        calendar.timeZone = TimeZone(identifier: "America/Vancouver")!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func testWithNothingPublishedItIsOffAndKeepsNothing() {
        XCTAssertEqual(NotTodayOutside.record(now: date(26), defaults: defaults, calendar: calendar), .off)
        XCTAssertTrue(NotTodayOutside.take(from: defaults).isEmpty)
    }

    func testKeepsTheMomentAndMarksTheDay() {
        NotTodaySnapshot.write(words, to: defaults)

        let outcome = NotTodayOutside.record(now: date(26), defaults: defaults, calendar: calendar)

        XCTAssertEqual(outcome, .setAside("Today is set aside"))
        XCTAssertEqual(NotTodaySnapshot.read(from: defaults)?.day, "2026-11-26")
        XCTAssertEqual(NotTodayOutside.take(from: defaults), [Int64(date(26).timeIntervalSince1970 * 1000)])
        // taken once
        XCTAssertTrue(NotTodayOutside.take(from: defaults).isEmpty)
    }

    func testASecondAskTheSameDayKeepsNothingMore() {
        NotTodaySnapshot.write(words, to: defaults)
        _ = NotTodayOutside.record(now: date(26), defaults: defaults, calendar: calendar)

        let again = NotTodayOutside.record(now: date(26, hour: 20), defaults: defaults, calendar: calendar)

        XCTAssertEqual(again, .already("Today is set aside"))
        XCTAssertEqual(NotTodayOutside.take(from: defaults).count, 1)
    }

    func testTheNextDayCanBeSetAsideAgain() {
        NotTodaySnapshot.write(words, to: defaults)
        _ = NotTodayOutside.record(now: date(26), defaults: defaults, calendar: calendar)

        let next = NotTodayOutside.record(now: date(27), defaults: defaults, calendar: calendar)

        XCTAssertEqual(next, .setAside("Today is set aside"))
        XCTAssertEqual(NotTodayOutside.take(from: defaults).count, 2)
    }

    func testWhatDartPublishesKeepsTheDayOfAMomentItHasNotTaken() {
        NotTodaySnapshot.write(words, to: defaults)
        let now = Date()
        _ = NotTodayOutside.record(now: now, defaults: defaults)

        // Dart, not knowing of it yet, says today is free
        ShortcutsChannel.publishNotToday(["label": "Not today", "done": "Today is set aside"], to: defaults, now: now)
        XCTAssertEqual(NotTodaySnapshot.read(from: defaults)?.day, NotTodaySnapshot.day(of: now))

        // once taken and, say, undone in the app, Dart's word stands
        _ = NotTodayOutside.take(from: defaults)
        ShortcutsChannel.publishNotToday(["label": "Not today", "done": "Today is set aside"], to: defaults, now: now)
        XCTAssertNil(NotTodaySnapshot.read(from: defaults)?.day)
    }

    func testTheDayIsNamedAsDartNamesItWhateverTheDevicesCalendar() {
        // a phone on the Buddhist calendar is in 2569; Dart says 2026
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        XCTAssertEqual(NotTodaySnapshot.day(of: date(26), calendar: buddhist).prefix(4), "2569")

        var gregorian = NotTodaySnapshot.gregorian
        gregorian.timeZone = calendar.timeZone
        XCTAssertEqual(NotTodaySnapshot.day(of: date(26), calendar: gregorian), "2026-11-26")
        XCTAssertEqual(NotTodaySnapshot.gregorian.identifier, .gregorian)
    }

    func testPublishingNothingTakesItAway() {
        NotTodaySnapshot.write(words, to: defaults)

        ShortcutsChannel.publishNotToday(nil, to: defaults)

        XCTAssertNil(NotTodaySnapshot.read(from: defaults))
    }
}
