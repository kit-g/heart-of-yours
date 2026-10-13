import AppIntents
import SwiftUI
import WidgetKit

/// The Goals widget (#368): the user's active goals and how close each is,
/// as the profile's Goals card shows them. Small, one goal — the one picked in
/// its edit sheet, the closest to done until then; medium, up to three. With
/// no active goal it says what a goal would show, and a tap adds one.
///
/// Copy: the English strings here are keys into the extension's
/// `Localizable.xcstrings`, as [TrainingWidget]'s are; the goals' own words
/// come from Dart, in the app's language.
///
/// Adding the widget is the opt-in: nothing in the app changes either way.
@available(iOS 17, *)
struct GoalsWidget: Widget {
    /// The profile, where the goals live.
    private static let profile = URL(string: "heart:///profile")

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: GoalsSnapshot.kind, intent: GoalsWidgetIntent.self, provider: GoalsProvider()) { entry in
            GoalsView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
                .widgetURL(Self.profile)
        }
        .configurationDisplayName("Goals")
        .description("Your progress toward your active goals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// A goal the small widget can show, as Dart last published them.
@available(iOS 17, *)
struct GoalChoice: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Goal")
    static let defaultQuery = GoalChoiceQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

@available(iOS 17, *)
struct GoalChoiceQuery: EntityQuery {
    private var all: [GoalChoice] {
        (GoalsSnapshot.read()?.goals ?? []).map { GoalChoice(id: $0.id, title: $0.title) }
    }

    func entities(for identifiers: [String]) async throws -> [GoalChoice] {
        all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [GoalChoice] {
        all
    }
}

@available(iOS 17, *)
struct GoalsWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Goals"
    static let description = IntentDescription("Your progress toward your active goals.")

    @Parameter(title: "Goal")
    var goal: GoalChoice?
}

@available(iOS 17, *)
struct GoalsEntry: TimelineEntry {
    let date: Date
    let goals: [GoalsSnapshot.Goal]
    /// The small widget's pick; nil until the user picks, which shows the
    /// closest to done.
    let pick: String?
    let accent: (light: UInt32, dark: UInt32)?
}

@available(iOS 17, *)
struct GoalsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GoalsEntry {
        entry(GoalsSnapshot.sample, pick: nil)
    }

    /// The gallery shows a goal rather than none; a widget on the Home Screen
    /// shows only the user's own.
    func snapshot(for configuration: GoalsWidgetIntent, in context: Context) async -> GoalsEntry {
        let snapshot = GoalsSnapshot.read() ?? (context.isPreview ? .sample : nil)
        return entry(snapshot, pick: configuration.goal?.id)
    }

    /// The app reloads the timeline whenever the goals or their progress
    /// change; nothing here moves with the clock.
    func timeline(for configuration: GoalsWidgetIntent, in context: Context) async -> Timeline<GoalsEntry> {
        Timeline(entries: [entry(GoalsSnapshot.read(), pick: configuration.goal?.id)], policy: .never)
    }

    private func entry(_ snapshot: GoalsSnapshot?, pick: String?) -> GoalsEntry {
        GoalsEntry(
            date: .now,
            goals: snapshot?.goals ?? [],
            pick: pick,
            accent: TrainingSnapshot.read().map { ($0.accent, $0.accentDark) }
        )
    }
}

@available(iOS 17, *)
private struct GoalsView: View {
    let entry: GoalsEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let accent = switch (scheme, entry.accent) {
        case (.dark, let accent?): Color(argb: accent.dark)
        case (_, let accent?): Color(argb: accent.light)
        case (_, nil): Color.accentColor
        }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("Goals")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                HeartMark()
                    .stroke(.primary, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            switch (family, shown) {
            case (_, []):
                Spacer(minLength: 6)
                empty(accent: accent)
            case (.systemMedium, let goals):
                // the goals hang from the heading: one goal leaves room
                // below rather than floating at the bottom
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(goals, id: \.id) { goal in
                        GoalLine(goal: goal, accent: accent, titleLines: 1)
                    }
                }
                .padding(.top, 8)
                Spacer(minLength: 0)
            case (_, let goals):
                Spacer(minLength: 6)
                GoalLine(goal: goals[0], accent: accent, titleLines: 3)
            }
        }
    }

    /// The small widget's one goal — the picked one while it is still active,
    /// else the closest to done — or the medium widget's three.
    private var shown: [GoalsSnapshot.Goal] {
        switch family {
        case .systemMedium:
            return Array(entry.goals.prefix(3))
        default:
            let picked = entry.goals.first { $0.id == entry.pick } ?? entry.goals.first
            return picked.map { [$0] } ?? []
        }
    }

    /// No active goal: what one would show, and the way to add it.
    private func empty(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set a goal and see how close you are, right here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Label("Add a goal", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
        }
    }
}

/// A goal as the profile's row has it: the title, where the user is, and a
/// bar to the current rung.
@available(iOS 17, *)
private struct GoalLine: View {
    let goal: GoalsSnapshot.Goal
    let accent: Color
    let titleLines: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: goal.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(titleLines)
                .minimumScaleFactor(0.85)
            Text(verbatim: goal.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(4, proxy.size.width * min(max(goal.progress, 0), 1)))
                }
            }
            .frame(height: 5)
            .accessibilityHidden(true)
        }
    }
}

extension GoalsSnapshot {
    /// What the widget gallery shows: one goal part of the way there.
    static let sample = GoalsSnapshot(goals: [
        Goal(id: "sample", title: "Workouts", status: "3 / 4", progress: 0.75),
    ])
}
