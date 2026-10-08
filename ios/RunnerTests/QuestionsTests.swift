import XCTest
@testable import Runner

/// The assistant's questions (#288): what the native side keeps for them and
/// how it says an answer. The answers themselves are Dart's, tested there.
@available(iOS 17, *)
final class QuestionsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "QuestionsTests")
        defaults.removePersistentDomain(forName: "QuestionsTests")
    }

    func testExercisesRoundTripByIdAndName() {
        ShortcutsChannel.storeExercises(
            [["id": "e1", "name": "Bench Press"], ["id": "e2", "name": "Squat"], ["name": "no id"], ["id": 3]],
            in: defaults
        )
        let stored = ShortcutsChannel.exercises(in: defaults)
        XCTAssertEqual(stored.map(\.id), ["e1", "e2"], "entries without both fields are dropped")
        XCTAssertEqual(stored.map(\.name), ["Bench Press", "Squat"])
    }

    func testEmptyCatalogueIsEmpty() {
        XCTAssertEqual(ShortcutsChannel.exercises(in: defaults).count, 0)
        ShortcutsChannel.storeExercises([], in: defaults)
        XCTAssertEqual(ShortcutsChannel.exercises(in: defaults).count, 0, "off publishes nothing to name")
    }

    func testExerciseEntityIsNamedByItsLocalizedName() {
        let entity = ExerciseEntity(id: "e1", name: "Жим лёжа")
        XCTAssertEqual(entity.id, "e1")
        XCTAssertEqual(String(localized: entity.displayRepresentation.title), "Жим лёжа")
    }

    /// The whole path, headless engine included: a question with no session
    /// is answered by Dart, in Dart's words, with the app's UI never up.
    func testTheEngineAnswersWithoutASession() async {
        let answer = await QuestionsEngine.shared.ask("weekly", userId: nil)
        XCTAssertEqual(answer, "No workouts yet")
        // the second question rides the running engine
        let again = await QuestionsEngine.shared.ask("record", exerciseId: "nope", userId: nil)
        XCTAssertEqual(again, "No workouts yet")
    }

    func testDialogSaysTheAnswerOrThatItCouldNot() {
        XCTAssertEqual(Questions.spoken("3 workouts this week"), "3 workouts this week")
        XCTAssertEqual(Questions.spoken(nil), "Heart could not answer that right now")
    }
}
