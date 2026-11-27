import AppIntents
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

/// "Not today" as it can be asked for from outside the app (#445): the words
/// Dart publishes over `heart/shortcuts` for it, in the app's language, and
/// the day already set aside. There is one only while the feature is on
/// (`Feature.notToday`), someone is signed in and no workout is running;
/// without one, the widget has no tile for it and the action says it is off.
///
/// Compiled into both, like [StartSnapshot], and kept in the same app group:
/// the app writes it, the widget and the action read it, and whichever of
/// them is asked marks the day itself, so the answer shows before Dart has
/// recorded anything.
struct NotTodaySnapshot: Codable, Equatable {
    /// "Not today", on the tile.
    var label: String
    /// "Today is set aside": what the tile says once it is, and the action's answer.
    var done: String
    /// The device's day ("2026-11-26") that is already set aside, if one is.
    var day: String?

    private static let key = "notToday"

    /// The control's kind (iOS 18), named here so that the action, which the
    /// app compiles too, can reload it.
    static let controlKind = "HeartNotToday"

    static func read(from defaults: UserDefaults? = TrainingSnapshot.suite) -> NotTodaySnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NotTodaySnapshot.self, from: data)
    }

    /// Stores [snapshot], or clears it; answers whether anything changed.
    @discardableResult
    static func write(_ snapshot: NotTodaySnapshot?, to defaults: UserDefaults? = TrainingSnapshot.suite) -> Bool {
        guard let defaults, read(from: defaults) != snapshot else { return false }
        switch snapshot {
        case let snapshot?: defaults.set(try? JSONEncoder().encode(snapshot), forKey: key)
        case nil: defaults.removeObject(forKey: key)
        }
        return true
    }

    /// Redraws what shows it: the Start widget's tile, and the control.
    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: StartSnapshot.kind)
        if #available(iOS 18, *) {
            ControlCenter.shared.reloadControls(ofKind: controlKind)
        }
    }

    /// The calendar the day is named in: Gregorian, as Dart's `DateTime` is,
    /// in the device's time zone. The device's own may be another (Buddhist,
    /// Japanese), whose year would never match what Dart publishes.
    static var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// [date]'s day as Dart names it: the device's own day, Gregorian.
    static func day(of date: Date, calendar: Calendar = gregorian) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Whether [date]'s day is the one already set aside.
    func setAside(on date: Date, calendar: Calendar = NotTodaySnapshot.gregorian) -> Bool {
        day == Self.day(of: date, calendar: calendar)
    }
}

/// Recording a "Not today" asked for outside the app (#445). Nothing here
/// writes a skip: Dart is the only writer, as for every second actor (#141).
/// This keeps the moment it was asked, in the app group, until Dart takes it
/// — at once when the app is alive to be told ([handoff]), else when it next
/// comes to the front — and marks the day in the snapshot meanwhile, so the
/// widget and a second ask already say it is set aside.
enum NotTodayOutside {
    static let pendingKey = "notToday.pending"

    /// Tells Dart there is a moment to take. Set by the app
    /// (`ShortcutsChannel`); nil in the extension, where there is no Dart.
    nonisolated(unsafe) static var handoff: (() -> Void)?

    enum Outcome: Equatable {
        /// Kept, with the words that say so.
        case setAside(String)
        /// Today was set aside before this.
        case already(String)
        /// Nothing published: the feature is off, nobody is signed in, a
        /// workout is running, or the app has not said yet since it launched.
        case off
    }

    static func record(
        now: Date = Date(),
        defaults: UserDefaults? = TrainingSnapshot.suite,
        calendar: Calendar = NotTodaySnapshot.gregorian
    ) -> Outcome {
        guard let defaults, var snapshot = NotTodaySnapshot.read(from: defaults) else { return .off }
        guard !snapshot.setAside(on: now, calendar: calendar) else { return .already(snapshot.done) }
        let kept = defaults.array(forKey: pendingKey) as? [NSNumber] ?? []
        defaults.set(kept + [NSNumber(value: Int64(now.timeIntervalSince1970 * 1000))], forKey: pendingKey)
        snapshot.day = NotTodaySnapshot.day(of: now, calendar: calendar)
        NotTodaySnapshot.write(snapshot, to: defaults)
        return .setAside(snapshot.done)
    }

    /// The moments kept, oldest first, in milliseconds since 1970; asking
    /// clears them.
    static func take(from defaults: UserDefaults? = TrainingSnapshot.suite) -> [Int64] {
        let kept = defaults?.array(forKey: pendingKey) as? [NSNumber] ?? []
        defaults?.removeObject(forKey: pendingKey)
        return kept.map(\.int64Value)
    }

    /// Whether a moment still waiting for Dart falls on [date]'s day: until
    /// Dart has recorded it, what Dart publishes does not know of it.
    static func waiting(
        on date: Date,
        in defaults: UserDefaults? = TrainingSnapshot.suite,
        calendar: Calendar = .current
    ) -> Bool {
        let kept = defaults?.array(forKey: pendingKey) as? [NSNumber] ?? []
        return kept.contains { calendar.isDate(Date(timeIntervalSince1970: $0.doubleValue / 1000), inSameDayAs: date) }
    }
}

/// "Not today": sets today aside without opening the app (#445). The Start
/// widget's tile and the control run it, and it is an action in the Shortcuts
/// app, so a shortcut, the Action button or Siri by that shortcut's name can.
///
/// Compiled into both: in the app's process it tells Dart at once; in the
/// extension's there is no Dart, and the app takes the moment when it next
/// comes to the front.
@available(iOS 17, *)
struct NotTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Not today"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = NotTodayOutside.record()
        NotTodaySnapshot.reload()
        NotTodayOutside.handoff?()
        return .result(dialog: Self.dialog(outcome))
    }

    /// What the action answers: Dart's own words once there are some, the
    /// catalog's while Dart has published none — which is the feature off,
    /// but also a workout running or nobody signed in, so the line says what
    /// to do, not which of them it was.
    static func dialog(_ outcome: NotTodayOutside.Outcome) -> IntentDialog {
        switch outcome {
        case let .setAside(words), let .already(words):
            return IntentDialog(stringLiteral: words)
        case .off:
            return IntentDialog("Heart can't set today aside right now. Open Heart, and check that Not today is on in its settings.")
        }
    }
}
