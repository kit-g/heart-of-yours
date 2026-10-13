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
        // the Lock Screen's and StandBy's too (#365)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

@available(iOS 17, *)
enum TrainingMetricOption: String, AppEnum, CaseIterable {
    case volume, workouts, duration, sets, reps
    // health (#366): offered only while the app publishes them
    case restingHeartRate, sleep, steps, bodyMass

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Data Type")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .volume: "Volume",
        .workouts: "Workouts",
        .duration: "Duration",
        .sets: "Sets",
        .reps: "Reps",
        .restingHeartRate: "Resting heart rate",
        .sleep: "Sleep",
        .steps: "Steps",
        .bodyMass: "Body mass",
    ]

    /// What a Lock Screen circle (#365) wears over its number.
    var symbol: String {
        switch self {
        case .volume: "dumbbell"
        case .workouts: "figure.strengthtraining.traditional"
        case .duration: "clock"
        case .sets: "square.stack"
        case .reps: "arrow.triangle.2.circlepath"
        case .restingHeartRate: "heart"
        case .sleep: "bed.double"
        case .steps: "figure.walk"
        case .bodyMass: "scalemass"
        }
    }

    var measure: TrainingMeasure {
        switch self {
        case .volume: .training(.volume)
        case .workouts: .training(.workouts)
        case .duration: .training(.duration)
        case .sets: .training(.sets)
        case .reps: .training(.reps)
        case .restingHeartRate: .health(.restingHeartRate)
        case .sleep: .health(.sleep)
        case .steps: .health(.steps)
        case .bodyMass: .health(.bodyMass)
        }
    }

    /// What a widget set to this draws from [snapshot]: itself, or, for a
    /// health type the app no longer publishes (health off, or forgotten),
    /// volume, as if the health types had never been built.
    func shown(in snapshot: TrainingSnapshot?) -> Self {
        switch measure {
        case .training: self
        case .health(let kind): snapshot?.offers(kind) == true ? self : .volume
        }
    }
}

/// What the widget counts: the training (#161) or a health metric (#366).
enum TrainingMeasure {
    case training(TrainingMetric)
    case health(HealthKind)
}

/// The edit sheet's data types: the training's always, a health metric's only
/// while the app publishes it — health off, the sheet looks as it did before
/// they were built.
@available(iOS 17, *)
struct TrainingMetricOptions: DynamicOptionsProvider {
    func results() async throws -> [TrainingMetricOption] {
        let snapshot = TrainingSnapshot.read()
        return TrainingMetricOption.allCases.filter { $0.shown(in: snapshot) == $0 }
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

    /// The range where there's no room for "Last" (#365): 7 days, 3 months.
    var short: String.LocalizationValue {
        switch self {
        case .week: "7 days"
        case .quarter: "3 months"
        }
    }
}

@available(iOS 17, *)
struct TrainingWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Training"
    static let description = IntentDescription("Your volume, workouts, time, sets or reps over the last 7 days or 3 months.")

    @Parameter(title: "Data Type", default: .volume, optionsProvider: TrainingMetricOptions())
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
        return TrainingEntry(date: .now, metric: configuration.metric.shown(in: snapshot), range: configuration.range, snapshot: snapshot)
    }

    /// One entry now, and the next after midnight, when the window moves on a
    /// day. The app reloads the timeline whenever the training changes.
    func timeline(for configuration: TrainingWidgetIntent, in context: Context) async -> Timeline<TrainingEntry> {
        let snapshot = TrainingSnapshot.read()
        let entry = TrainingEntry(date: .now, metric: configuration.metric.shown(in: snapshot), range: configuration.range, snapshot: snapshot)
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
        let measure = entry.metric.measure
        let unit = entry.snapshot?.unit ?? .metric
        let (bars, total) = figures(measure)
        // a health value is the user's body: hidden until the phone is unlocked
        let health = switch measure {
        case .training: false
        case .health: true
        }
        let averaged = switch measure {
        case .training: false
        case .health(let kind): kind.averaged
        }
        let value = formatted(total, measure, unit: unit)
        // 58 bpm is a day's, not the week's: said so where there's room
        let caption = switch averaged {
        case true: "\(String(localized: "Daily average")) · \(String(localized: entry.range.short))"
        case false: TrainingRangeOption.caseDisplayRepresentations[entry.range].map { String(localized: $0.title) } ?? ""
        }
        let accent = switch (scheme, entry.snapshot) {
        case (.dark, let snapshot?): Color(argb: snapshot.accentDark)
        case (_, let snapshot?): Color(argb: snapshot.accent)
        case (_, nil): Color.accentColor
        }
        let headline = VStack(alignment: .leading, spacing: 0) {
            Text(TrainingMetricOption.caseDisplayRepresentations[entry.metric]?.title ?? "")
                .font(.headline)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 30, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .privacySensitive(health)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        // the text first: the bars take whatever height it leaves, and would
        // otherwise squeeze the total down to its minimum scale
        .layoutPriority(1)
        let chart = TrainingBars(bars: bars, range: entry.range.range, accent: accent, relative: averaged)
            .privacySensitive(health)

        switch family {
        case .accessoryInline:
            // one line above the clock: 617 lbs · 7 days
            Text("\(value) · \(String(localized: entry.range.short))")
                .privacySensitive(health)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.metric.symbol)
                        .font(.caption)
                    Text(compact(total, measure, unit: unit))
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .privacySensitive(health)
                    Text(String(localized: entry.range.short))
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
            }
        case .accessoryRectangular:
            // tinted or vibrant on the Lock Screen: the bars in the
            // foreground's own colour, never the accent
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // what the number counts: "3" alone could be anything
                    Image(systemName: entry.metric.symbol)
                        .font(.caption)
                    Text(value)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .privacySensitive(health)
                    Spacer(minLength: 0)
                    Text(String(localized: entry.range.short))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                TrainingBars(bars: bars, range: entry.range.range, accent: .primary, relative: averaged)
                    .privacySensitive(health)
            }
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

    /// The bars of the entry's window and the figure it comes to; nil, a
    /// health window without a reading.
    private func figures(_ measure: TrainingMeasure) -> (bars: [TrainingBar], total: Double?) {
        let snapshot = entry.snapshot ?? .empty
        switch measure {
        case .training(let metric):
            let bars = snapshot.bars(metric, entry.range.range, now: entry.date)
            return (bars, bars.map(\.value).reduce(0, +))
        case .health(let kind):
            return snapshot.health(kind, entry.range.range, now: entry.date)
        }
    }

    /// 23K, 12, 3h, 58: what fits a circle, without its unit.
    private func compact(_ total: Double?, _ measure: TrainingMeasure, unit: TrainingSnapshot.Unit) -> String {
        guard let value = total else { return "–" }
        let metric: TrainingMetric
        switch measure {
        case .training(let training):
            metric = training
        case .health(.sleep):
            return compactDuration(value * 60)
        case .health(.bodyMass):
            return Int(weight(value, unit).rounded()).formatted()
        case .health(.restingHeartRate), .health(.steps):
            return Int(value.rounded()).formatted(.number.notation(.compactName))
        }
        switch metric {
        case .volume:
            let shown = switch unit {
            case .imperial: value * 2.20462262
            case .metric: value
            }
            return Int(shown.rounded()).formatted(.number.notation(.compactName))
        case .duration:
            return compactDuration(value)
        case .workouts, .sets, .reps:
            return Int(value.rounded()).formatted(.number.notation(.compactName))
        }
    }

    private func compactDuration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 3600 ? [.hour] : [.minute]
        return formatter.string(from: seconds) ?? ""
    }

    /// Kilograms in [unit].
    private func weight(_ kilograms: Double, _ unit: TrainingSnapshot.Unit) -> Double {
        switch unit {
        case .imperial: kilograms * 2.20462262
        case .metric: kilograms
        }
    }

    /// 617 lbs, 12, 3h 20m, 58 bpm, 81.4 kg: in the user's unit and locale; a
    /// dash for a health window without a reading.
    private func formatted(_ total: Double?, _ measure: TrainingMeasure, unit: TrainingSnapshot.Unit) -> String {
        guard let value = total else { return "–" }
        let metric: TrainingMetric
        switch measure {
        case .training(let training):
            metric = training
        case .health(.restingHeartRate):
            return "\(Int(value.rounded()).formatted()) \(String(localized: "bpm"))"
        case .health(.sleep):
            return duration(value * 60)
        case .health(.steps):
            return Int(value.rounded()).formatted()
        case .health(.bodyMass):
            let label = switch unit {
            case .imperial: String(localized: "lbs")
            case .metric: String(localized: "kg")
            }
            return "\(weight(value, unit).formatted(.number.precision(.fractionLength(1)))) \(label)"
        }
        switch metric {
        case .volume:
            let (shown, label) = switch unit {
            case .imperial: (value * 2.20462262, String(localized: "lbs"))
            case .metric: (value, String(localized: "kg"))
            }
            return "\(Int(shown.rounded()).formatted()) \(label)"
        case .duration:
            return duration(value)
        case .workouts, .sets, .reps:
            return Int(value.rounded()).formatted()
        }
    }

    private func duration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: seconds) ?? ""
    }
}

/// The bars and their labels: a weekday under each day, or a month's initial
/// under the week it begins in. An empty window draws a flat baseline.
@available(iOS 17, *)
private struct TrainingBars: View {
    let bars: [TrainingBar]
    let range: TrainingRange
    let accent: Color
    /// Bars for readings around a level (resting heart rate, body mass): drawn
    /// from below the lowest rather than from zero, where they'd all look
    /// the same height.
    var relative = false

    var body: some View {
        let highest = bars.map(\.value).max() ?? 0
        let lowest = bars.map(\.value).filter { $0 > 0 }.min() ?? 0
        let floor = relative ? max(0, lowest - (highest - lowest)) : 0
        let calendar = Calendar.training
        HStack(alignment: .bottom, spacing: range == .week ? 6 : 3) {
            ForEach(bars, id: \.start) { bar in
                VStack(spacing: 4) {
                    GeometryReader { proxy in
                        let share = switch (bar.value > 0, highest > floor) {
                        case (false, _): 0.0
                        case (true, true): (bar.value - floor) / (highest - floor)
                        case (true, false): 1.0
                        }
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
