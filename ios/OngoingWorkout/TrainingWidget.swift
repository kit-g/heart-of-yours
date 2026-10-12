import AppIntents
import SwiftUI
import WidgetKit

/// The training widget (#161): a total and its bars, for what the user picks
/// in the widget's edit sheet — volume, workouts, time, sets or reps, over the
/// last 7 days or the last 3 months. iOS draws the edit sheet from
/// [TrainingWidgetIntent]'s parameters.
///
/// Copy: the English strings here are keys into the extension's
/// `Localizable.xcstrings`, generated on translation import
/// (`shared/heart_language`); a test holds the two to the same words.
///
/// Adding the widget is the opt-in: nothing in the app changes either way.
@available(iOS 17, *)
struct TrainingWidget: Widget {
    /// The profile, where the same training is charted.
    private static let profile = URL(string: "heart:///profile")

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: TrainingSnapshot.kind, intent: TrainingWidgetIntent.self, provider: TrainingProvider()) { entry in
            TrainingView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
                .widgetURL(Self.profile)
        }
        .configurationDisplayName("Training")
        .description("Your volume, workouts, time, sets or reps over the last 7 days or 3 months.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(iOS 17, *)
enum TrainingMetricOption: String, AppEnum {
    case volume, workouts, duration, sets, reps

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Data Type")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .volume: "Volume",
        .workouts: "Workouts",
        .duration: "Duration",
        .sets: "Sets",
        .reps: "Reps",
    ]

    var metric: TrainingMetric {
        switch self {
        case .volume: .volume
        case .workouts: .workouts
        case .duration: .duration
        case .sets: .sets
        case .reps: .reps
        }
    }
}

@available(iOS 17, *)
enum TrainingRangeOption: String, AppEnum {
    case week, quarter

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Date Range")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .week: "Last 7 days",
        .quarter: "Last 3 months",
    ]

    var range: TrainingRange {
        switch self {
        case .week: .week
        case .quarter: .quarter
        }
    }
}

@available(iOS 17, *)
struct TrainingWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Training"
    static let description = IntentDescription("Your volume, workouts, time, sets or reps over the last 7 days or 3 months.")

    @Parameter(title: "Data Type", default: .volume)
    var metric: TrainingMetricOption

    @Parameter(title: "Date Range", default: .week)
    var range: TrainingRangeOption
}

@available(iOS 17, *)
struct TrainingEntry: TimelineEntry {
    let date: Date
    let metric: TrainingMetricOption
    let range: TrainingRangeOption
    /// Nil: nobody's training to show, drawn as zeros.
    let snapshot: TrainingSnapshot?
}

@available(iOS 17, *)
struct TrainingProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TrainingEntry {
        TrainingEntry(date: .now, metric: .volume, range: .week, snapshot: .sample(now: .now))
    }

    /// The gallery shows a week of training rather than an empty chart; a
    /// widget on the Home Screen shows only the user's own.
    func snapshot(for configuration: TrainingWidgetIntent, in context: Context) async -> TrainingEntry {
        let snapshot = TrainingSnapshot.read() ?? (context.isPreview ? .sample(now: .now) : nil)
        return TrainingEntry(date: .now, metric: configuration.metric, range: configuration.range, snapshot: snapshot)
    }

    /// One entry now, and the next after midnight, when the window moves on a
    /// day. The app reloads the timeline whenever the training changes.
    func timeline(for configuration: TrainingWidgetIntent, in context: Context) async -> Timeline<TrainingEntry> {
        let entry = TrainingEntry(date: .now, metric: configuration.metric, range: configuration.range, snapshot: TrainingSnapshot.read())
        let calendar = Calendar.training
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now.addingTimeInterval(86_400)
        return Timeline(entries: [entry], policy: .after(midnight))
    }
}

@available(iOS 17, *)
private struct TrainingView: View {
    let entry: TrainingEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let metric = entry.metric.metric
        let unit = entry.snapshot?.unit ?? .metric
        let bars = (entry.snapshot ?? .empty).bars(metric, entry.range.range, now: entry.date)
        let total = bars.map(\.value).reduce(0, +)
        let accent = switch (scheme, entry.snapshot) {
        case (.dark, let snapshot?): Color(argb: snapshot.accentDark)
        case (_, let snapshot?): Color(argb: snapshot.accent)
        case (_, nil): Color.accentColor
        }
        let headline = VStack(alignment: .leading, spacing: 0) {
            Text(TrainingMetricOption.caseDisplayRepresentations[entry.metric]?.title ?? "")
                .font(.headline)
                .lineLimit(1)
            Text(formatted(total, metric, unit: unit))
                .font(.system(size: 30, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(TrainingRangeOption.caseDisplayRepresentations[entry.range]?.title ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        // the text first: the bars take whatever height it leaves, and would
        // otherwise squeeze the total down to its minimum scale
        .layoutPriority(1)
        let chart = TrainingBars(bars: bars, range: entry.range.range, accent: accent)

        switch family {
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    headline
                    Spacer(minLength: 4)
                    mark
                }
                .frame(maxWidth: 150, alignment: .leading)
                chart
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 4) {
                    headline
                    Spacer(minLength: 0)
                    mark
                }
                chart
            }
        }
    }

    private var mark: some View {
        HeartMark()
            .stroke(.primary, lineWidth: 2)
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
    }

    /// 617 lbs, 12, 3h 20m: whole numbers, in the user's unit and locale.
    private func formatted(_ value: Double, _ metric: TrainingMetric, unit: TrainingSnapshot.Unit) -> String {
        switch metric {
        case .volume:
            let (shown, label) = switch unit {
            case .imperial: (value * 2.20462262, String(localized: "lbs"))
            case .metric: (value, String(localized: "kg"))
            }
            return "\(Int(shown.rounded()).formatted()) \(label)"
        case .duration:
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.allowedUnits = value >= 3600 ? [.hour, .minute] : [.minute]
            formatter.zeroFormattingBehavior = .dropLeading
            return formatter.string(from: value) ?? ""
        case .workouts, .sets, .reps:
            return Int(value.rounded()).formatted()
        }
    }
}

/// The bars and their labels: a weekday under each day, or a month's initial
/// under the week it begins in. An empty window draws a flat baseline.
@available(iOS 17, *)
private struct TrainingBars: View {
    let bars: [TrainingBar]
    let range: TrainingRange
    let accent: Color

    var body: some View {
        let highest = bars.map(\.value).max() ?? 0
        let calendar = Calendar.training
        HStack(alignment: .bottom, spacing: range == .week ? 6 : 3) {
            ForEach(bars, id: \.start) { bar in
                VStack(spacing: 4) {
                    GeometryReader { proxy in
                        let share = highest > 0 ? bar.value / highest : 0
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(bar.value > 0 ? accent : Color.secondary.opacity(0.25))
                                .frame(height: max(3, proxy.size.height * share))
                        }
                    }
                    Text(label(of: bar, calendar: calendar))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func label(of bar: TrainingBar, calendar: Calendar) -> String {
        switch range {
        case .week:
            return calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: bar.start) - 1]
        case .quarter:
            // the month's initial under the week its first day falls in
            let first = (0..<7)
                .compactMap { calendar.date(byAdding: .day, value: $0, to: bar.start) }
                .first { calendar.component(.day, from: $0) == 1 }
            return first.map { calendar.veryShortMonthSymbols[calendar.component(.month, from: $0) - 1] } ?? " "
        }
    }
}

extension TrainingSnapshot {
    /// Nobody's training: zeros.
    static let empty = TrainingSnapshot(unit: .metric, accent: 0, accentDark: 0, days: [:])

    /// A plausible week for the widget gallery: three sessions, in the
    /// default theme's accent (Ink's cobalt).
    static func sample(now: Date) -> TrainingSnapshot {
        let calendar = Calendar.training
        let today = calendar.startOfDay(for: now)
        let sessions: [(Int, [Double])] = [
            (5, [4_200, 1, 3_600, 18, 140]),
            (3, [3_100, 1, 3_000, 15, 120]),
            (1, [5_000, 1, 4_200, 21, 160]),
        ]
        let days = sessions.reduce(into: [String: [Double]]()) { days, session in
            if let day = calendar.date(byAdding: .day, value: -session.0, to: today) {
                days[date(day, calendar: calendar)] = session.1
            }
        }
        return TrainingSnapshot(unit: .metric, accent: 0xFF1F4EC8, accentDark: 0xFF93ADFF, days: days)
    }
}
