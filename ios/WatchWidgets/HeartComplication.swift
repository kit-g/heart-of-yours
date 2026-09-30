import SwiftUI
import WidgetKit

/// Heart on the watch face (#186): the workout at a glance while one is
/// running, the Heart mark otherwise — and a tap opens the app either way.
///
/// Deliberately not relevant to the Smart Stack: on watchOS 11 and later the
/// lock screen's Live Activity (#133) already surfaces the workout there, and
/// the user should never see the same workout twice.
@main
struct HeartComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartWorkout", provider: Provider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Heart")
        .supportedFamilies([.accessoryCorner, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let workout: ComplicationSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, workout: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, workout: ComplicationSnapshot.read()))
    }

    /// One entry now, and one when the rest ends, so a countdown that runs
    /// out stops counting on its own. Nothing else is scheduled: the watch app
    /// reloads the timeline whenever the workout changes, and a complication
    /// that guessed ahead would show stale data — worse than the plain mark.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let workout = ComplicationSnapshot.read()
        var entries = [Entry(date: .now, workout: workout)]
        if let rest = workout?.rest, rest.upperBound > .now {
            var after = workout
            after?.restStart = nil
            after?.restEnd = nil
            entries.append(Entry(date: rest.upperBound, workout: after))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct ComplicationView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch (family, entry.workout) {
        case (.accessoryRectangular, let workout?):
            VStack(alignment: .leading, spacing: 1) {
                Text(workout.exercise)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                if let rest = workout.rest {
                    Text(timerInterval: rest, countsDown: true)
                        .font(.body.monospacedDigit())
                } else {
                    Text(workout.next)
                        .font(.body)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case (.accessoryCircular, let workout?):
            if let rest = workout.rest {
                ProgressView(timerInterval: rest, countsDown: true) {
                    Mark()
                }
                .progressViewStyle(.circular)
                .widgetAccentable()
            } else {
                Mark()
            }
        case (.accessoryCorner, let workout?):
            Mark()
                .widgetLabel {
                    if let rest = workout.rest {
                        Text(timerInterval: rest, countsDown: true)
                    } else {
                        Text(workout.exercise)
                    }
                }
        case (.accessoryInline, let workout?):
            if let rest = workout.rest {
                Text(timerInterval: rest, countsDown: true)
            } else {
                Text(workout.exercise)
            }
        default:
            // idle, switched off, or never opened: the mark, which opens Heart
            Mark()
        }
    }
}

/// The Heart mark as the watch face can tint it.
struct Mark: View {
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.title3)
            .widgetAccentable()
            .accessibilityLabel("Heart")
    }
}
