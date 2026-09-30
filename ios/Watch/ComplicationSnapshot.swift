import Foundation

/// What the watch-face complication shows (#186), handed from the watch app to
/// its widget extension through their shared app group.
///
/// Compiled into both. The app writes it whenever what the phone sent changes
/// something the complication draws; the widget only reads it. Nothing health-
/// related is ever in it — the complication shows where the workout is, not
/// what the body is doing.
struct ComplicationSnapshot: Codable, Equatable {
    var exercise: String
    var next: String
    var restStart: Date?
    var restEnd: Date?
    var restLabel: String?

    var rest: ClosedRange<Date>? {
        guard let restStart, let restEnd, restStart < restEnd else { return nil }
        return restStart...restEnd
    }

    /// `group.<the phone app's bundle id>`, from the target's Info.plist, where
    /// the build settings put it.
    static var suite: UserDefaults? {
        (Bundle.main.object(forInfoDictionaryKey: "HeartAppGroup") as? String).flatMap(UserDefaults.init(suiteName:))
    }

    private static let key = "complication"

    /// The workout in progress, or nil when there is none — idle, switched
    /// off, or never set up.
    static func read() -> ComplicationSnapshot? {
        guard let data = suite?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ComplicationSnapshot.self, from: data)
    }

    /// Stores [snapshot], or clears it; answers whether anything changed, so
    /// the caller reloads the widget only when there is something to redraw.
    @discardableResult
    static func write(_ snapshot: ComplicationSnapshot?) -> Bool {
        guard read() != snapshot, let suite else { return false }
        switch snapshot {
        case let snapshot?:
            suite.set(try? JSONEncoder().encode(snapshot), forKey: key)
        case nil:
            suite.removeObject(forKey: key)
        }
        return true
    }
}
