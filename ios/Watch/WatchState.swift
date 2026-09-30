import SwiftUI

/// What the phone last said to show (#182) — `lib/core/env/watch.dart`'s
/// `WatchState`, decoded. The phone is the only writer; this is a picture of
/// its state, never a copy to edit.
///
/// Every string is finished copy from Dart, which owns localisation and unit
/// formatting. The watch translates nothing.
enum WatchState: Equatable {
    /// Nothing from the phone yet: first launch, before the phone has answered.
    case awaiting
    case workout(Workout)
    /// No workout running.
    case idle(String)
    /// Switched off in the phone's Settings.
    case off(String)

    struct Workout: Equatable {
        var workoutId: String
        var startedAt: Date
        var title: String
        var exercise: String
        var next: String
        var rest: Rest?
        var accent: Color

        struct Rest: Equatable {
            var window: ClosedRange<Date>
            var label: String
            /// Shown once the countdown has run out and the phone has not been
            /// back to say so.
            var over: String
        }
    }

    /// Decodes a context or message as the phone sends it; nil for anything
    /// it doesn't recognise, which leaves the current state standing.
    init?(_ payload: [String: Any]) {
        func date(_ key: String) -> Date? {
            (payload[key] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        }

        switch payload["state"] as? String {
        case "idle":
            guard let message = payload["message"] as? String else { return nil }
            self = .idle(message)
        case "off":
            guard let message = payload["message"] as? String else { return nil }
            self = .off(message)
        case "workout":
            guard let workoutId = payload["workoutId"] as? String,
                  let startedAt = date("startedAt"),
                  let title = payload["title"] as? String,
                  let exercise = payload["exercise"] as? String,
                  let next = payload["next"] as? String
            else { return nil }

            let rest: Workout.Rest? = switch (date("restStart"), date("restEnd"), payload["restLabel"] as? String, payload["restOver"] as? String) {
            case let (start?, end?, label?, over?) where start < end:
                .init(window: start...end, label: label, over: over)
            default:
                nil
            }

            self = .workout(.init(
                workoutId: workoutId,
                startedAt: startedAt,
                title: title,
                exercise: exercise,
                next: next,
                rest: rest,
                accent: Color(argb: (payload["accent"] as? NSNumber)?.uint32Value ?? 0xFFFF_FFFF)
            ))
        default:
            return nil
        }
    }
}

extension Color {
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}
