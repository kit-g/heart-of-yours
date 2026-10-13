import Foundation

/// What the training widget (#161) draws from: the user's finished workouts
/// per day, as Dart counted them, handed from the app to the widget extension
/// through their shared app group.
///
/// Compiled into both. The app writes it whenever Dart publishes a change on
/// `heart/widgets`; the widget only reads it, and picks its own window from
/// the days and today's date, so the bars roll over at midnight with the app
/// closed. And, while the app's health mirror has them, the health metrics
/// the widget can show instead (#366): device-only, drawn here and nowhere
/// else, redacted while the phone is locked.
struct TrainingSnapshot: Codable, Equatable {
    enum Unit: String, Codable {
        case metric, imperial
    }

    /// The widget's kind, which the app names to reload its timelines.
    static let kind = "HeartTraining"

    /// The unit a volume is shown in; volumes are stored in kilograms.
    var unit: Unit
    /// `Color.toARGB32()` of the theme's accent, light and dark.
    var accent: UInt32
    var accentDark: UInt32
    /// `yyyy-MM-dd` => `[volume kg, workouts, seconds, sets, reps]`, in
    /// `Metric` order; days without a workout are absent.
    var days: [String: [Double]]
    /// `HealthKind` raw value => `yyyy-MM-dd` => the day's value (#366);
    /// a kind absent, nothing of it to offer.
    var health: [String: [String: Double]]?

    /// From what Dart sends on the channel; nil for anything it doesn't
    /// recognise.
    init?(map: Any?) {
        guard let map = map as? [String: Any],
              JSONSerialization.isValidJSONObject(map),
              let data = try? JSONSerialization.data(withJSONObject: map),
              let decoded = try? JSONDecoder().decode(TrainingSnapshot.self, from: data)
        else { return nil }
        self = decoded
    }

    init(unit: Unit, accent: UInt32, accentDark: UInt32, days: [String: [Double]], health: [String: [String: Double]]? = nil) {
        self.unit = unit
        self.accent = accent
        self.accentDark = accentDark
        self.days = days
        self.health = health
    }

    /// `group.<the phone app's bundle id>`, from the target's Info.plist, where
    /// the build settings put it.
    static var suite: UserDefaults? {
        (Bundle.main.object(forInfoDictionaryKey: "HeartAppGroup") as? String).flatMap(UserDefaults.init(suiteName:))
    }

    private static let key = "training"

    /// The user's training, or nil when there is nobody's to show — signed
    /// out, or the app not opened since the widget arrived.
    static func read(from defaults: UserDefaults? = suite) -> TrainingSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TrainingSnapshot.self, from: data)
    }

    /// Stores [snapshot], or clears it; answers whether anything changed, so
    /// the caller reloads the widget only when there is something to redraw.
    @discardableResult
    static func write(_ snapshot: TrainingSnapshot?, to defaults: UserDefaults? = suite) -> Bool {
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

/// What the widget counts. The raw value is the index into a day's totals.
enum TrainingMetric: Int, CaseIterable {
    case volume, workouts, duration, sets, reps
}

/// A health data type the widget can show (#366), by the key Dart publishes it
/// under: a reading a day for resting heart rate and body mass, a night's sleep
/// in minutes, the day's steps.
enum HealthKind: String, CaseIterable {
    case restingHeartRate
    case sleep = "sleepAsleep"
    case steps
    case bodyMass

    /// Whether a window's figure is its days' average, not their sum: a week
    /// of resting heart rates adds up to nothing.
    var averaged: Bool { self != .steps }
}

/// The widget's window: the last 7 days, a bar each, or the last 13 weeks
/// from a Monday, a bar each — the app's weeks start on Monday everywhere.
enum TrainingRange: CaseIterable {
    case week, quarter
}

/// One bar: the day or week it starts on, and its total.
struct TrainingBar: Equatable {
    let start: Date
    let value: Double
}

extension TrainingSnapshot {
    /// The bars of [range] ending today, oldest first, in the stored units.
    func bars(_ metric: TrainingMetric, _ range: TrainingRange, now: Date, calendar: Calendar = .training) -> [TrainingBar] {
        let today = calendar.startOfDay(for: now)
        switch range {
        case .week:
            return (0..<7).reversed().compactMap { back in
                calendar.date(byAdding: .day, value: -back, to: today).map { day in
                    TrainingBar(start: day, value: value(of: metric, on: day, calendar: calendar))
                }
            }
        case .quarter:
            return Self.weeks(ending: today, calendar: calendar).map { start in
                let total = Self.days(of: start, calendar: calendar)
                    .map { value(of: metric, on: $0, calendar: calendar) }
                    .reduce(0, +)
                return TrainingBar(start: start, value: total)
            }
        }
    }

    /// Whether the app published [kind] (#366): health on, and read.
    func offers(_ kind: HealthKind) -> Bool {
        health?[kind.rawValue] != nil
    }

    /// [kind]'s bars over [range] ending today, oldest first, and the figure
    /// the window comes to: steps summed, the rest averaged over the days with
    /// a reading. A week's bar is the same: steps summed, the rest averaged.
    /// Nil for a window without a single reading.
    func health(_ kind: HealthKind, _ range: TrainingRange, now: Date, calendar: Calendar = .training) -> (bars: [TrainingBar], total: Double?) {
        let readings = health?[kind.rawValue] ?? [:]
        let today = calendar.startOfDay(for: now)
        func reading(_ day: Date) -> Double? { readings[Self.date(day, calendar: calendar)] }
        func combined(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            let sum = values.reduce(0, +)
            return kind.averaged ? sum / Double(values.count) : sum
        }
        switch range {
        case .week:
            let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            let bars = days.map { TrainingBar(start: $0, value: reading($0) ?? 0) }
            return (bars, combined(days.compactMap(reading)))
        case .quarter:
            let weeks = Self.weeks(ending: today, calendar: calendar)
            let bars = weeks.map { start in
                TrainingBar(start: start, value: combined(Self.days(of: start, calendar: calendar).compactMap(reading)) ?? 0)
            }
            let days = weeks.flatMap { Self.days(of: $0, calendar: calendar) }.filter { $0 <= today }
            return (bars, combined(days.compactMap(reading)))
        }
    }

    /// The Mondays of the 13 weeks ending with [today]'s, oldest first.
    private static func weeks(ending today: Date, calendar: Calendar) -> [Date] {
        let weekday = calendar.component(.weekday, from: today)
        // Sunday is 1, Monday 2: this many days since Monday
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today) ?? today
        return (0..<13).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: monday) }
    }

    /// The seven days of the week that begins on [start].
    private static func days(of start: Date, calendar: Calendar) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func value(of metric: TrainingMetric, on day: Date, calendar: Calendar) -> Double {
        let totals = days[Self.date(day, calendar: calendar)] ?? []
        return totals.indices.contains(metric.rawValue) ? totals[metric.rawValue] : 0
    }

    /// `yyyy-MM-dd` of [day] in [calendar], as Dart keys the days.
    static func date(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

extension Calendar {
    /// The calendar Dart counts days in: Gregorian, in the device's zone,
    /// whatever calendar the user reads dates in.
    static var training: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = .current
        return calendar
    }
}
