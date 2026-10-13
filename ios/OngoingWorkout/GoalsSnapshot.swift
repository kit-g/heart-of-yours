import Foundation

/// What the Goals widget (#368) draws from: the user's active goals, worded
/// and measured in Dart exactly as the profile's goal rows are, closest to
/// done first. Handed from the app to the widget extension through their
/// shared app group, as [TrainingSnapshot] is.
///
/// Compiled into both. The app writes it whenever Dart publishes a change on
/// `heart/widgets`; the widget only reads it.
struct GoalsSnapshot: Codable, Equatable {
    struct Goal: Codable, Equatable {
        let id: String
        /// "Bench Press (Barbell) — Estimated 1RM"
        let title: String
        /// "2 / 4 · per week"
        let status: String
        /// 0 to 1 toward the current rung.
        let progress: Double
    }

    /// The widget's kind, which the app names to reload its timelines.
    static let kind = "HeartGoals"

    var goals: [Goal]

    /// From what Dart sends on the channel; nil for anything it doesn't
    /// recognise.
    init?(map: Any?) {
        guard let map = map as? [String: Any],
              JSONSerialization.isValidJSONObject(map),
              let data = try? JSONSerialization.data(withJSONObject: map),
              let decoded = try? JSONDecoder().decode(GoalsSnapshot.self, from: data)
        else { return nil }
        self = decoded
    }

    init(goals: [Goal]) {
        self.goals = goals
    }

    private static let key = "goals"

    /// The user's goals, or nil when there are nobody's to show — signed out,
    /// or the app not opened since the widget arrived.
    static func read(from defaults: UserDefaults? = TrainingSnapshot.suite) -> GoalsSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GoalsSnapshot.self, from: data)
    }

    /// Stores [snapshot], or clears it; answers whether anything changed.
    @discardableResult
    static func write(_ snapshot: GoalsSnapshot?, to defaults: UserDefaults? = TrainingSnapshot.suite) -> Bool {
        guard let defaults, read(from: defaults) != snapshot else { return false }
        switch snapshot {
        case let snapshot?:
            defaults.set(try? JSONEncoder().encode(snapshot), forKey: key)
        case nil:
            defaults.removeObject(forKey: key)
        }
        return true
    }
}
