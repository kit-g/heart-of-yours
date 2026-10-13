import Foundation
import WidgetKit

/// What the Start widget (#367) offers: the templates Dart publishes over
/// `heart/shortcuts` for the icon's menu and Siri, and whether the shortcut
/// links work at all (`Feature.shortcuts`). Handed from the app to the widget
/// extension through their shared app group, as [TrainingSnapshot] is.
///
/// Compiled into both. The app writes it whenever Dart publishes either half;
/// the widget only reads it.
struct StartSnapshot: Codable, Equatable {
    struct Template: Codable, Equatable {
        let id: String
        let name: String
    }

    /// The widget's kind, which the app names to reload its timelines.
    static let kind = "HeartStart"

    /// Whether `heart://app/start` starts anything; off, the feature's link is
    /// an unknown route (#284).
    var enabled: Bool
    /// The user's own templates, then the samples; empty with the feature off.
    var templates: [Template]

    private static let key = "start"

    /// Nobody's templates and no link to trust: a tap opens the workout tab.
    static let none = StartSnapshot(enabled: false, templates: [])

    static func read(from defaults: UserDefaults? = TrainingSnapshot.suite) -> StartSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StartSnapshot.self, from: data)
    }

    /// Stores [snapshot]; answers whether anything changed.
    @discardableResult
    static func write(_ snapshot: StartSnapshot, to defaults: UserDefaults? = TrainingSnapshot.suite) -> Bool {
        guard let defaults, read(from: defaults) != snapshot else { return false }
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: key)
        return true
    }

    /// Keeps what Dart last published and redraws the widget when it changed.
    static func publish(enabled: Bool, templates: [(id: String, name: String)]) {
        let snapshot = StartSnapshot(enabled: enabled, templates: templates.map { Template(id: $0.id, name: $0.name) })
        if write(snapshot) {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    /// Where a tap goes: the template's start link, a blank workout's for a
    /// nil [template] — or, with the feature off, the workout tab, so that the
    /// tap still lands somewhere a workout can be started.
    func link(template: String?) -> URL {
        guard enabled else { return URL(string: "heart:///workout")! }
        var components = URLComponents()
        components.scheme = "heart"
        components.host = "app"
        components.path = "/start"
        if let template {
            components.queryItems = [URLQueryItem(name: "template", value: template)]
        }
        return components.url!
    }
}
