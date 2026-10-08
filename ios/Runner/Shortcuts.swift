import AppIntents
import Flutter
import Foundation
import UIKit
import os

/// Siri, the Shortcuts app and Spotlight driving Heart (#285): the intents
/// open the app on a `heart://app/…` link (#284) and the app does the rest, so
/// nothing here reads or writes the workout. The one thing an intent needs
/// with the app not running — the templates it can name — Dart publishes over
/// the `heart/shortcuts` channel and `ShortcutsChannel` keeps in UserDefaults.
///
/// Copy: intent and parameter titles are in `Localizable.xcstrings`, the Siri
/// phrases in `<lang>.lproj/AppShortcuts.strings` (the App Shortcuts build
/// step takes no catalog below an iOS 17 target); both are generated on
/// translation import (`shared/heart_language`), and the phrases in
/// `HeartShortcuts` have to match the tables' English keys word for word,
/// which a test checks.

private let log = Logger(subsystem: "me.heart-of", category: "Shortcuts")

/// The links an intent opens the app on. The verbs are Dart's (`ShortcutLink`).
enum ShortcutURL {
    static func start(template: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "heart"
        components.host = "app"
        components.path = "/start"
        if let template {
            components.queryItems = [URLQueryItem(name: "template", value: template)]
        }
        return components.url!
    }

    static let finish = URL(string: "heart://app/finish")!
}

/// A template, as Dart last published it: the user's own and the samples.
@available(iOS 16, *)
struct TemplateEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Template")
    static let defaultQuery = TemplateQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 16, *)
struct TemplateQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [TemplateEntity] {
        ShortcutsChannel.templates.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TemplateEntity] {
        ShortcutsChannel.templates
    }

    /// "Start push day": matched against the names, case and diacritics aside.
    func entities(matching string: String) async throws -> [TemplateEntity] {
        ShortcutsChannel.templates.filter {
            $0.name.range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

/// Opens the app on [url]. The app is already in the foreground when this
/// runs (`openAppWhenRun`), so it may open its own scheme and the link lands
/// in Flutter like any other. (`OpenURLIntent`, the system's own way, needs
/// iOS 18.)
@available(iOS 16, *)
@MainActor
private func open(_ url: URL) -> some IntentResult {
    UIApplication.shared.open(url)
    return .result()
}

@available(iOS 16, *)
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let openAppWhenRun = true

    @Parameter(title: "Template")
    var template: TemplateEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$template)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        open(ShortcutURL.start(template: template?.id))
    }
}

@available(iOS 16, *)
struct FinishWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish Workout"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        open(ShortcutURL.finish)
    }
}

/// The phrases Siri answers to, and the tiles in the Shortcuts app and
/// Spotlight. iOS 17: the tile's title and symbol arrived with it, and the
/// intents above are still actions in the Shortcuts app on iOS 16.
///
/// String literals only, matching `AppShortcuts.strings`: the build reads
/// them out of the source.
@available(iOS 17, *)
struct HeartShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout in \(.applicationName)",
                "Start \(\.$template) in \(.applicationName)",
            ],
            shortTitle: "Start a workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: FinishWorkoutIntent(),
            phrases: [
                "Finish my workout in \(.applicationName)",
            ],
            shortTitle: "Finish workout",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: StartRestIntent(),
            phrases: [
                "Start rest in \(.applicationName)",
                "Rest for \(\.$length) in \(.applicationName)",
            ],
            shortTitle: "Start rest",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: AddRestIntent(),
            phrases: [
                "Add \(\.$length) to my rest in \(.applicationName)",
            ],
            shortTitle: "Extend rest",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: EndRestIntent(),
            phrases: [
                "Skip rest in \(.applicationName)",
            ],
            shortTitle: "Skip rest",
            systemImageName: "forward.end"
        )
        AppShortcut(
            intent: LogSetIntent(),
            phrases: [
                "Log a set in \(.applicationName)",
            ],
            shortTitle: "Log a set",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: PersonalRecordIntent(),
            phrases: [
                "What's my \(\.$exercise) record in \(.applicationName)",
            ],
            shortTitle: "Personal record",
            systemImageName: "trophy"
        )
        AppShortcut(
            intent: LastExerciseIntent(),
            phrases: [
                "When did I last do \(\.$exercise) in \(.applicationName)",
            ],
            shortTitle: "Last time",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: LastTemplateIntent(),
            phrases: [
                "When did I last train \(\.$template) in \(.applicationName)",
            ],
            shortTitle: "Last session",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: WorkoutsThisWeekIntent(),
            phrases: [
                "How many workouts this week in \(.applicationName)",
            ],
            shortTitle: "Workouts this week",
            systemImageName: "chart.bar"
        )
    }
}

/// The app's half of the `heart/shortcuts` channel: Dart publishes the
/// templates, this keeps them for the intents and tells the system the
/// template phrases changed, so Siri learns the names.
enum ShortcutsChannel {
    private static let templatesKey = "shortcuts.templates"
    static let restKey = "shortcuts.rest"
    static let setKey = "shortcuts.nextSet"
    static let sessionKey = "shortcuts.userId"
    static let exercisesKey = "shortcuts.exercises"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "heart/shortcuts", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "setTemplates":
                guard let list = call.arguments as? [[String: Any]] else {
                    return result(FlutterError(code: "bad_arguments", message: "setTemplates needs a list", details: nil))
                }
                store(list)
                refresh()
                result(nil)
            case "setRest":
                // the rest a voice command acts on (#98), or nothing to act on
                switch call.arguments {
                case let rest as [String: Any]:
                    UserDefaults.standard.set(rest, forKey: restKey)
                default:
                    UserDefaults.standard.removeObject(forKey: restKey)
                }
                result(nil)
            case "setNextSet":
                // the set a voice command logs (#287), or nothing left
                switch call.arguments {
                case let set as [String: Any]:
                    UserDefaults.standard.set(set, forKey: setKey)
                default:
                    UserDefaults.standard.removeObject(forKey: setKey)
                }
                result(nil)
            case "setSession":
                // whose training the questions are about (#288)
                switch call.arguments {
                case let userId as String:
                    UserDefaults.standard.set(userId, forKey: sessionKey)
                default:
                    UserDefaults.standard.removeObject(forKey: sessionKey)
                }
                result(nil)
            case "setExercises":
                guard let list = call.arguments as? [[String: Any]] else {
                    return result(FlutterError(code: "bad_arguments", message: "setExercises needs a list", details: nil))
                }
                storeExercises(list)
                refresh()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// Called at launch too: the system's copy of the parameters is only as
    /// fresh as the last time it was told.
    static func refresh() {
        if #available(iOS 17, *) {
            HeartShortcuts.updateAppShortcutParameters()
        }
    }

    /// The catalogue as Dart published it (#288), for [ExerciseEntity].
    @available(iOS 16, *)
    static var exercises: [ExerciseEntity] { exercises(in: .standard) }

    @available(iOS 16, *)
    static func exercises(in defaults: UserDefaults) -> [ExerciseEntity] {
        let stored = defaults.array(forKey: exercisesKey) as? [[String: String]] ?? []
        return stored.compactMap { entry in
            guard let id = entry["id"], let name = entry["name"] else { return nil }
            return ExerciseEntity(id: id, name: name)
        }
    }

    static func storeExercises(_ list: [[String: Any]], in defaults: UserDefaults = .standard) {
        let exercises = list.compactMap { entry -> [String: String]? in
            guard let id = entry["id"] as? String, let name = entry["name"] as? String else { return nil }
            return ["id": id, "name": name]
        }
        defaults.set(exercises, forKey: exercisesKey)
    }

    @available(iOS 16, *)
    static var templates: [TemplateEntity] { templates(in: .standard) }

    @available(iOS 16, *)
    static func templates(in defaults: UserDefaults) -> [TemplateEntity] {
        let stored = defaults.array(forKey: templatesKey) as? [[String: String]] ?? []
        return stored.compactMap { entry in
            guard let id = entry["id"], let name = entry["name"] else { return nil }
            return TemplateEntity(id: id, name: name)
        }
    }

    /// Keeps what Dart published, as [templates] reads it back.
    static func store(_ list: [[String: Any]], in defaults: UserDefaults = .standard) {
        let templates = list.compactMap { entry -> [String: String]? in
            guard let id = entry["id"] as? String, let name = entry["name"] as? String else { return nil }
            return ["id": id, "name": name]
        }
        defaults.set(templates, forKey: templatesKey)
    }
}
