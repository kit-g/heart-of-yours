import ActivityKit
import Foundation

/// The active workout on the lock screen and in the Dynamic Island (#133).
///
/// Compiled into both the app (which starts, updates and ends the activity,
/// `Runner/OngoingWorkoutChannel.swift`) and the widget extension (which draws
/// it) — ActivityKit matches the two by this type.
///
/// Every string arrives as finished copy from Dart, which owns localisation and
/// unit formatting; nothing here is translated. The clocks are instants, not
/// counts: the views tick them natively, so the app only sends an update when
/// something changes.
@available(iOS 16.1, *)
struct OngoingWorkoutAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The workout's name.
        var title: String
        /// The exercise the user is on; empty for a workout with none yet.
        var exercise: String
        /// The set they are about to do; empty when there is nothing to say.
        var next: String

        /// The rest countdown's window, while one runs.
        var restStart: Date?
        var restEnd: Date?
        var restLabel: String?
        /// Shown once the countdown has run out and the app has not been back
        /// to say so — the activity goes stale at [restEnd].
        var restOver: String?

        /// The user's theme, per appearance, as ARGB. The lock screen follows
        /// the system appearance rather than the app's.
        var accent: UInt32
        var accentDark: UInt32
        var accentInk: UInt32
        var accentInkDark: UInt32

        var rest: ClosedRange<Date>? {
            guard let restStart, let restEnd, restStart < restEnd else { return nil }
            return restStart...restEnd
        }
    }

    /// Identity: an activity belongs to exactly one workout, which is how a
    /// relaunched app re-attaches to it instead of starting a second one.
    var workoutId: String
    var startedAt: Date
}
