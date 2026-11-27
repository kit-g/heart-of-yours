import AppIntents
import SwiftUI
import WidgetKit

/// The Start widget (#367): one tap from the Home Screen into a workout.
/// Small, the whole widget starts one thing — the template picked in its edit
/// sheet, the first one until then, or an empty workout; medium, "Start a
/// workout" and up to three templates, each its own tap. Every tap opens the
/// same link the icon's menu does (#356), so the app decides what happens.
///
/// Copy: the English strings here are keys into the extension's
/// `Localizable.xcstrings`, as [TrainingWidget]'s are.
///
/// Adding the widget is the opt-in: nothing in the app changes either way.
@available(iOS 17, *)
struct StartWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: StartSnapshot.kind, intent: StartWidgetIntent.self, provider: StartProvider()) { entry in
            StartView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Start")
        .description("Start a workout or one of your templates in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// What the small widget starts: a template, or an empty workout (the empty
/// id).
@available(iOS 17, *)
struct StartChoice: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Template")
    static let defaultQuery = StartChoiceQuery()
    static let empty = StartChoice(id: "", name: "")

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        switch id.isEmpty {
        case true: DisplayRepresentation(title: "Empty workout")
        case false: DisplayRepresentation(title: "\(name)")
        }
    }
}

@available(iOS 17, *)
struct StartChoiceQuery: EntityQuery {
    /// The templates as last published, then the empty workout.
    private var all: [StartChoice] {
        (StartSnapshot.read() ?? .none).templates.map { StartChoice(id: $0.id, name: $0.name) } + [.empty]
    }

    func entities(for identifiers: [String]) async throws -> [StartChoice] {
        all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [StartChoice] {
        all
    }
}

@available(iOS 17, *)
struct StartWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Start"
    static let description = IntentDescription("Start a workout or one of your templates in one tap.")

    @Parameter(title: "Template")
    var choice: StartChoice?
}

@available(iOS 17, *)
struct StartEntry: TimelineEntry {
    let date: Date
    let snapshot: StartSnapshot
    /// The small widget's pick; nil until the user picks, which starts the
    /// first template.
    let choice: StartChoice?
    /// `Color.toARGB32()` of the theme's accent, from the training snapshot;
    /// nil before the app has published one.
    let accent: (light: UInt32, dark: UInt32)?
    /// "Not today" (#445), while it can be asked for; nil, the widget has no
    /// tile for it.
    var notToday: NotTodaySnapshot? = nil
}

@available(iOS 17, *)
struct StartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StartEntry {
        entry(.sample, choice: nil)
    }

    /// The gallery shows a few templates rather than none; a widget on the
    /// Home Screen shows only the user's own.
    func snapshot(for configuration: StartWidgetIntent, in context: Context) async -> StartEntry {
        let snapshot = StartSnapshot.read() ?? (context.isPreview ? .sample : .none)
        return entry(snapshot, choice: configuration.choice)
    }

    /// One thing here changes with the clock: a day set aside (#445) is over
    /// at midnight, so a second entry starts the next day, when the tile
    /// offers "Not today" again. The app reloads the timeline whenever the
    /// templates or either feature change.
    func timeline(for configuration: StartWidgetIntent, in context: Context) async -> Timeline<StartEntry> {
        let snapshot = StartSnapshot.read() ?? .none
        // by the calendar, not by 24 hours: a day the clocks change is not 24 long
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(24 * 60 * 60)
        return Timeline(
            entries: [
                entry(snapshot, choice: configuration.choice),
                entry(snapshot, choice: configuration.choice, date: tomorrow),
            ],
            policy: .never
        )
    }

    private func entry(_ snapshot: StartSnapshot, choice: StartChoice?, date: Date = .now) -> StartEntry {
        let training = TrainingSnapshot.read()
        return StartEntry(
            date: date,
            snapshot: snapshot,
            choice: choice,
            accent: training.map { ($0.accent, $0.accentDark) },
            // the gallery's sample is the Start widget as everyone has it
            notToday: snapshot == .sample ? nil : NotTodaySnapshot.read()
        )
    }
}

@available(iOS 17, *)
private struct StartView: View {
    let entry: StartEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let accent = switch (scheme, entry.accent) {
        case (.dark, let accent?): Color(argb: accent.dark)
        case (_, let accent?): Color(argb: accent.light)
        case (_, nil): Color.accentColor
        }
        switch family {
        case .systemMedium:
            medium(accent: accent)
        default:
            small(accent: accent)
        }
    }

    /// One tap target, as a small widget is: what the edit sheet picked, while
    /// it is still a template the app publishes.
    private func small(accent: Color) -> some View {
        let templates = entry.snapshot.templates
        let template: StartSnapshot.Template? = switch entry.choice {
        case nil: templates.first
        case let choice? where choice.id.isEmpty: nil
        case let choice?: templates.first { $0.id == choice.id } ?? templates.first
        }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                StartBadge(template: template != nil, accent: accent, size: 40)
                Spacer(minLength: 0)
                HeartMark()
                    .stroke(.primary, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 4)
            title(template)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            // a template's name says what; the caption says it starts
            if template != nil {
                Text("Start")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .widgetURL(entry.snapshot.link(template: template?.id))
    }

    /// "Start a workout" and up to three templates, each its own tap; fewer
    /// templates, fewer tiles, and none leaves "Start a workout" the width.
    /// With "Not today" on (#445) the last tile is its, and the templates
    /// take the two between.
    private func medium(accent: Color) -> some View {
        let room = entry.notToday == nil ? 3 : 2
        let tiles: [StartTile] =
            [.start(nil)]
            + entry.snapshot.templates.prefix(room).map { .start($0) }
            + (entry.notToday.map { [.notToday($0)] } ?? [])
        let rows = stride(from: 0, to: tiles.count, by: 2).map { Array(tiles[$0..<min($0 + 2, tiles.count)]) }
        return VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(rows[row].indices, id: \.self) { column in
                        switch rows[row][column] {
                        case let .start(template): tile(template, accent: accent)
                        case let .notToday(notToday): tile(notToday)
                        }
                    }
                }
            }
        }
    }

    /// "Not today" (#445): a tap sets today aside where the widget is, with
    /// no app opened. Once the day is set aside the tile says so and is no
    /// longer a button, until the next day.
    @ViewBuilder
    private func tile(_ notToday: NotTodaySnapshot) -> some View {
        switch notToday.setAside(on: entry.date) {
        case true:
            tileBody(notToday.done, symbol: "checkmark")
        case false:
            Button(intent: NotTodayIntent()) {
                tileBody(notToday.label, symbol: "arrow.uturn.forward")
            }
            .buttonStyle(.plain)
        }
    }

    private func tileBody(_ words: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.18), in: Circle())
                .accessibilityHidden(true)
            Text(verbatim: words)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    /// A template's own name, as the user wrote it, or the empty workout's.
    private func title(_ template: StartSnapshot.Template?) -> Text {
        switch template {
        case let template?: Text(verbatim: template.name)
        case nil: Text("Start a workout")
        }
    }

    private func tile(_ template: StartSnapshot.Template?, accent: Color) -> some View {
        Link(destination: entry.snapshot.link(template: template?.id)) {
            HStack(spacing: 8) {
                StartBadge(template: template != nil, accent: accent, size: 28)
                title(template)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// What a tile of the medium widget is: a way to start, or "Not today".
@available(iOS 17, *)
private enum StartTile {
    case start(StartSnapshot.Template?)
    case notToday(NotTodaySnapshot)
}

/// "Not today" as a control (#445, iOS 18): on the Lock Screen, in Control
/// Centre and on the Action button, one press sets today aside. Controls
/// are declared in the binary and cannot be hidden per user: with the
/// feature off this one changes nothing, as the App Shortcuts do (#284).
@available(iOS 18, *)
struct NotTodayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: NotTodaySnapshot.controlKind) {
            ControlWidgetButton(action: NotTodayIntent()) {
                Label("Not today", systemImage: "arrow.uturn.forward")
            }
        }
        .displayName("Not today")
    }
}

/// The round mark of a tap: a plus for an empty workout, a dumbbell for a
/// template (as in the icon's menu).
@available(iOS 17, *)
private struct StartBadge: View {
    let template: Bool
    let accent: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: template ? "dumbbell.fill" : "plus")
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(accent, in: Circle())
            .accessibilityHidden(true)
    }
}

extension StartSnapshot {
    /// What the widget gallery shows: three templates, as a new user's samples
    /// would read.
    static let sample = StartSnapshot(
        enabled: true,
        templates: [
            Template(id: "sample-push", name: "Push Day"),
            Template(id: "sample-pull", name: "Pull Day"),
            Template(id: "sample-legs", name: "Leg Day"),
        ]
    )
}
