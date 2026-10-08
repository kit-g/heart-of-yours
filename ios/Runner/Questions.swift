import AppIntents
import Foundation

/// The assistant's questions about a person's training (#288): a record, the
/// last time, this week's count. Each is answered by the headless engine
/// (`QuestionsEngine`) in a sentence Dart wrote, and Siri says it. Training
/// data only, by construction: the engine's answers read the workout mirror
/// and nothing else.

/// An exercise of the catalogue, as Dart last published it: resolved by its
/// localized name, so "what's my bench press record" finds it.
@available(iOS 16, *)
struct ExerciseEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exercise")
    static let defaultQuery = ExerciseQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 16, *)
struct ExerciseQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ExerciseEntity] {
        ShortcutsChannel.exercises.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ExerciseEntity] {
        Array(ShortcutsChannel.exercises.prefix(20))
    }

    func entities(matching string: String) async throws -> [ExerciseEntity] {
        ShortcutsChannel.exercises.filter {
            $0.name.range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

@available(iOS 17, *)
enum Questions {
    /// The answer as Siri says it: Dart's sentence, or that there is none.
    static func dialog(_ answer: String?) -> IntentDialog {
        IntentDialog("\(spoken(answer))")
    }

    static func spoken(_ answer: String?) -> String {
        switch answer {
        case let answer?:
            return answer
        case nil:
            return String(localized: "Heart could not answer that right now")
        }
    }

    static var userId: String? { UserDefaults.standard.string(forKey: ShortcutsChannel.sessionKey) }
}

@available(iOS 17, *)
struct PersonalRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Personal Record"

    @Parameter(title: "Exercise")
    var exercise: ExerciseEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Personal record for \(\.$exercise)")
    }

    func perform() async throws -> some ProvidesDialog {
        let answer = await QuestionsEngine.shared.ask("record", exerciseId: exercise.id, userId: Questions.userId)
        return .result(dialog: Questions.dialog(answer))
    }
}

@available(iOS 17, *)
struct LastExerciseIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Time I Did an Exercise"

    @Parameter(title: "Exercise")
    var exercise: ExerciseEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Last time I did \(\.$exercise)")
    }

    func perform() async throws -> some ProvidesDialog {
        let answer = await QuestionsEngine.shared.ask("lastExercise", exerciseId: exercise.id, userId: Questions.userId)
        return .result(dialog: Questions.dialog(answer))
    }
}

@available(iOS 17, *)
struct LastTemplateIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Time I Did a Template"

    @Parameter(title: "Template")
    var template: TemplateEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Last time I did \(\.$template)")
    }

    func perform() async throws -> some ProvidesDialog {
        let answer = await QuestionsEngine.shared.ask("lastTemplate", template: template.name, userId: Questions.userId)
        return .result(dialog: Questions.dialog(answer))
    }
}

@available(iOS 17, *)
struct WorkoutsThisWeekIntent: AppIntent {
    static let title: LocalizedStringResource = "Workouts This Week"

    func perform() async throws -> some ProvidesDialog {
        let answer = await QuestionsEngine.shared.ask("weekly", userId: Questions.userId)
        return .result(dialog: Questions.dialog(answer))
    }
}
