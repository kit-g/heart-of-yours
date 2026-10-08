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
        XCTAssertEqual(ShortcutURL.start().absoluteString, "heart://app/start")
        XCTAssertEqual(
            ShortcutURL.start(template: "78d84f4d-abde-45bc-a592-b85006d33451").absoluteString,
            "heart://app/start?template=78d84f4d-abde-45bc-a592-b85006d33451"
        )
        XCTAssertEqual(ShortcutURL.finish.absoluteString, "heart://app/finish")
    }

    func testTemplateIdsAreEscapedInTheLink() {
        let url = ShortcutURL.start(template: "a b&c")
        XCTAssertEqual(url.scheme, "heart")
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
