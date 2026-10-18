import 'package:heart_models/heart_models.dart';

import 'lens.dart';
import 'weeks.dart';

/// How long a recap looks back: a calendar month (#154) or a calendar year
/// (#155).
enum RecapSpan { month, year }

/// The calendar month or year a recap covers, as the half-open [from, to) in
/// the user's own zone: midnight on the first day, and midnight on the first
/// day after.
///
/// A workout belongs to the period it started in, as every other count in the
/// app reads it, so a session across midnight on the last day counts once.
final class RecapPeriod {
  final RecapSpan span;
  final DateTime from;
  final DateTime to;

  const new _(this.span, this.from, this.to);

  /// [date]'s calendar month.
  factory month(DateTime date) {
    return RecapPeriod._(.month, DateTime(date.year, date.month), DateTime(date.year, date.month + 1));
  }

  /// The calendar year [year].
  factory year(int year) => RecapPeriod._(.year, DateTime(year), DateTime(year + 1));

  /// The period of the same span just before this one: last month, last year.
  RecapPeriod get previous {
    return switch (span) {
      .month => RecapPeriod.month(DateTime(from.year, from.month - 1)),
      .year => RecapPeriod.year(from.year - 1),
    };
  }

  bool contains(DateTime instant) => !instant.isBefore(from) && instant.isBefore(to);

  @override
  bool operator ==(Object other) => other is RecapPeriod && other.span == span && other.from == from;

  @override
  int get hashCode => Object.hash(span, from);

  @override
  String toString() => 'RecapPeriod($span, $from)';
}

/// A finished workout in the period: which one, when it started, and how long
/// it was trained — start to end, less its pauses (#134). Nothing else about
/// it: never its calories or any value read from HealthKit or Health Connect
/// (`docs/2026-09-05.health-data.md`).
typedef RecapWorkout = ({String id, DateTime start, Duration trained});

/// One completed working set — warm-ups are left out, as records and the
/// muscle map leave them out — with its workout, when that started, and what
/// the exercise is. The recap's unit of data.
///
/// [category] is null for an exercise the device no longer has a row for (a
/// dangling id): its sets still count, but it has no volume and no records,
/// because what its numbers measure is unknown. Weights are as stored, in
/// kilograms.
typedef RecapSet = ({
  String workoutId,
  String exerciseId,
  DateTime start,
  Category? category,
  Movement movement,
  MuscleTagging muscles,
  Target target,
  double? weight,
  int? reps,
  double? duration,
  double? distance,
});

/// What one key — a muscle group, a movement pattern — gathered over the
/// period: [sets], fractional as the lens counts them ([wholeSets] for
/// display), the [sessions] that touched it, and the [volume] of those sets
/// in the user's unit, shared out the way the sets are.
typedef RecapCount = ({double sets, int sessions, double volume});

/// One exercise's period: its working [sets], the [sessions] it was in, and
/// their [volume] in the user's unit (zero for anything that is not lifted).
typedef RecapExercise = ({String exerciseId, int sets, int sessions, double volume});

/// A personal record the period set and still holds at its end.
///
/// [record] is the key heart_models' [PersonalRecords.toPersonalRecords] uses
/// (`heaviest`, `oneRepMax`, `mostReps`, `longestDistance`…), and [value] is
/// that record's entry exactly as the fold gives it — what the exercise's own
/// records screen reads, so the two never disagree. Weights in it are stored
/// kilograms. [isFirst] marks a record with nothing earlier to beat: the
/// first time an exercise was ever done.
typedef RecapRecord = ({String exerciseId, Category category, String record, Map<String, Object> value});

/// A lifted exercise's best within the period alone (#155's "best lifts"):
/// its [heaviest] set and its best estimated [oneRepMax] (Brzycki), each an
/// entry as [PersonalRecords.toPersonalRecords] shapes it, weights in stored
/// kilograms.
typedef RecapLift = ({
  String exerciseId,
  Category category,
  Map<String, Object> heaviest,
  Map<String, Object>? oneRepMax,
});

extension RecapRecordReading on RecapRecord {
  /// Nothing came before it to beat: the exercise's first time.
  bool get isFirst => !value.containsKey('previous');
}

/// What a month or a year of training adds up to (#154, #155): one engine
/// behind the monthly report, the year in review and their share cards
/// (#166). Computed on the device from the local mirror and never stored, so
/// nothing is kept while the feature is off and nothing needs rebuilding when
/// it comes back on.
///
/// Every count is of working sets in finished workouts. Nothing here is
/// health data, and no field may become one: a share card renders straight
/// from this.
final class Recap {
  final RecapPeriod period;

  /// Finished workouts that started in the period.
  final int workouts;

  /// Their time, start to end, less pauses.
  final Duration trained;

  /// Distinct calendar days with a workout.
  final int trainingDays;

  /// Completed working sets.
  final int sets;

  /// Σ weight × reps over lifted sets, in the [weightUnit] the recap was asked
  /// for. Lifted means what a record counts as volume: barbell, dumbbell,
  /// machine and weighted body weight.
  final double volume;
  final MeasurementUnit weightUnit;

  /// Per muscle group, most sets first: the most-trained muscles are its
  /// first keys. By the muscle map's rule ([groupSharesOf]).
  final Map<MuscleGroupKey, RecapCount> muscles;

  /// Per movement pattern, most sets first, by the pattern lens's rule
  /// ([patternsOf]).
  final Map<String, RecapCount> patterns;

  /// Per exercise, most sets first, then most sessions: the most-logged. Ties
  /// keep the order the exercises were first done in.
  final List<RecapExercise> exercises;

  /// Records set in the period and still standing at its end, oldest first.
  final List<RecapRecord> records;

  /// Every lifted exercise's best in the period, the heaviest estimated
  /// one-rep max first.
  final List<RecapLift> lifts;

  /// Workouts per week, in the user's week, for every week of the period that
  /// has begun: zeros included, so a strip of them reads as the period's
  /// rhythm. A week across the period's edge counts only its days inside.
  final Map<DateTime, int> weeks;

  /// Workouts per calendar month of the period that has begun, zeros
  /// included: twelve of them, by December, for a year.
  final Map<DateTime, int> months;

  const new({
    required this.period,
    required this.workouts,
    required this.trained,
    required this.trainingDays,
    required this.sets,
    required this.volume,
    required this.weightUnit,
    required this.muscles,
    required this.patterns,
    required this.exercises,
    required this.records,
    required this.lifts,
    required this.weeks,
    required this.months,
  });

  /// Nothing was trained in the period: a recap with nothing to say.
  bool get isEmpty => workouts == 0;

  /// Weeks with at least one workout: consistency counted in weeks, with no
  /// streak to break.
  int get weeksTrained => weeks.values.where((count) => count > 0).length;
}

/// [period]'s [Recap], from [workouts] — the finished ones that started in
/// it — and [history]: every working set, oldest workout first and a
/// session's sets together, of each exercise trained in the period, from its
/// first time up to the period's end. The history before the period is what
/// says whether a record set in it beat anything.
///
/// Weeks start on [firstWeekday], the user's (#339). [now] bounds the weeks
/// and months of a period still under way, so a recap of this month lists no
/// week that has not begun.
Recap recapOf(
  RecapPeriod period, {
  required Iterable<RecapWorkout> workouts,
  required List<RecapSet> history,
  required int firstWeekday,
  required MeasurementUnit weightUnit,
  required DateTime now,
}) {
  final finished = workouts.where((workout) => period.contains(workout.start)).toList();
  final inPeriod = {for (final workout in finished) workout.id};
  final done = history.where((set) => inPeriod.contains(set.workoutId)).toList();

  double unit(double kilograms) {
    return switch (weightUnit) {
      .imperial => kilograms.asPounds,
      .metric => kilograms,
    };
  }

  // one row per exercise per session, as the lens counts them, each with the
  // volume of its sets
  final rows = _rowsOf(done);

  Map<K, RecapCount> byKey<K>(Map<K, double> Function(LensSets row) keysOf) {
    final counted = countByPeriod(
      rows.map((row) => row.lens),
      periods: [period.from],
      periodOf: (_) => period.from,
      keysOf: keysOf,
    )[period.from]!;
    final volumes = rows.fold(<K, double>{}, (volumes, row) {
      for (final MapEntry(:key, value: share) in keysOf(row.lens).entries.where((entry) => entry.value > 0)) {
        volumes.update(key, (volume) => volume + row.volume * share, ifAbsent: () => row.volume * share);
      }
      return volumes;
    });
    final entries = _sorted(
      counted.entries,
      (a, b) => switch (b.value.sets.compareTo(a.value.sets)) {
        0 => b.value.sessions.compareTo(a.value.sessions),
        final order => order,
      },
    );
    return {
      for (final MapEntry(:key, value: (:sets, :sessions)) in entries)
        key: (sets: sets, sessions: sessions, volume: unit(volumes[key] ?? 0)),
    };
  }

  final exercises = _exercisesOf(rows, unit);
  final starts = {for (final workout in finished) workout.id: workout.start};

  return Recap(
    period: period,
    workouts: finished.length,
    trained: finished.fold(Duration.zero, (sum, workout) => sum + workout.trained),
    trainingDays: finished
        .map((workout) => DateTime(workout.start.year, workout.start.month, workout.start.day))
        .toSet()
        .length,
    sets: done.length,
    volume: unit(rows.fold(0.0, (sum, row) => sum + row.volume)),
    weightUnit: weightUnit,
    muscles: byKey(muscleKeysOf),
    patterns: byKey(patternsOf),
    exercises: exercises,
    records: _recordsOf(history, inPeriod, starts),
    lifts: _liftsOf(done),
    weeks: _weeksOf(period, finished, firstWeekday: firstWeekday, now: now),
    months: _monthsOf(period, finished, now: now),
  );
}

/// [items] in [compare]'s order, ties kept in the order they came: a recap
/// read twice reads the same, which [List.sort] does not promise.
List<T> _sorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = items.indexed.toList()
    ..sort(
      (a, b) => switch (compare(a.$2, b.$2)) {
        0 => a.$1.compareTo(b.$1),
        final order => order,
      },
    );
  return indexed.map((each) => each.$2).toList();
}

/// A lens row and the kilograms its sets moved.
typedef _Row = ({LensSets lens, double volume});

/// Whether a set of [category] has volume: what a record counts as one.
bool _lifted(Category? category) {
  return switch (category) {
    .barbell || .dumbbell || .machine || .weightedBodyWeight => true,
    .assistedBodyWeight || .repsOnly || .cardio || .duration || .weightedDistance || .weightedDuration || null => false,
  };
}

RecordSet _recordSet(RecapSet set) {
  return RecordSet(
    weight: set.weight,
    reps: set.reps,
    duration: set.duration,
    distance: set.distance,
    workoutId: set.workoutId,
    at: set.start.toUtc().toIso8601String(),
  );
}

/// [sets] grouped by exercise, each group in the order it came.
Map<String, List<RecapSet>> _byExercise(Iterable<RecapSet> sets) {
  return sets.fold({}, (groups, set) => groups..putIfAbsent(set.exerciseId, () => []).add(set));
}

List<_Row> _rowsOf(Iterable<RecapSet> sets) {
  final grouped = sets.fold(<(String, String), List<RecapSet>>{}, (groups, set) {
    return groups..putIfAbsent((set.workoutId, set.exerciseId), () => []).add(set);
  });
  return grouped.values.map((group) {
    final first = group.first;
    return (
      lens: (
        workoutId: first.workoutId,
        exerciseId: first.exerciseId,
        start: first.start,
        movement: first.movement,
        muscles: first.muscles,
        target: first.target,
        sets: group.length,
      ),
      volume: switch (_lifted(first.category)) {
        true => group.map(_recordSet).fold(0.0, (sum, set) => sum + set.volume),
        false => 0.0,
      },
    );
  }).toList();
}

List<RecapExercise> _exercisesOf(List<_Row> rows, double Function(double) unit) {
  final grouped = rows.fold(<String, List<_Row>>{}, (groups, row) {
    return groups..putIfAbsent(row.lens.exerciseId, () => []).add(row);
  });
  final exercises = [
    for (final MapEntry(key: exerciseId, value: rows) in grouped.entries)
      (
        exerciseId: exerciseId,
        sets: rows.fold(0, (sum, row) => sum + row.lens.sets),
        sessions: rows.map((row) => row.lens.workoutId).toSet().length,
        volume: unit(rows.fold(0.0, (sum, row) => sum + row.volume)),
      ),
  ];
  return _sorted(
    exercises,
    (a, b) => switch (b.sets.compareTo(a.sets)) {
      0 => b.sessions.compareTo(a.sessions),
      final order => order,
    },
  );
}

/// The headline records of each exercise's [history], folded by the one
/// definition of a record, that a workout in the period holds: the totals,
/// `sessions`, `firstAt` and the rep-max table are not records anyone set.
List<RecapRecord> _recordsOf(List<RecapSet> history, Set<String> inPeriod, Map<String, DateTime> starts) {
  final records = [
    for (final MapEntry(key: exerciseId, value: sets) in _byExercise(history).entries)
      if (sets.first.category case final Category category)
        if (sets.map(_recordSet).toList().toPersonalRecords(category) case final Map<String, Object> folded)
          for (final MapEntry(key: record, :value) in folded.entries)
            if (value case final Map entry && {'workoutId': final String holder} when inPeriod.contains(holder))
              (exerciseId: exerciseId, category: category, record: record, value: entry.cast<String, Object>()),
  ];
  DateTime at(RecapRecord record) => starts[record.value['workoutId']]!;
  return _sorted(records, (a, b) => at(a).compareTo(at(b)));
}

/// Each lifted exercise's heaviest set and best estimate within [done] alone.
List<RecapLift> _liftsOf(List<RecapSet> done) {
  Map<String, Object> alone(Object entry) => {...(entry as Map).cast<String, Object>()}..remove('previous');

  final lifts = [
    for (final MapEntry(key: exerciseId, value: sets) in _byExercise(done).entries)
      if (sets.first.category case final Category category when _lifted(category))
        if (sets.map(_recordSet).toList().toPersonalRecords(category)
            case {'heaviest': final Object heaviest} && final folded)
          (
            exerciseId: exerciseId,
            category: category,
            heaviest: alone(heaviest),
            oneRepMax: switch (folded['oneRepMax']) {
              final Object best => alone(best),
              null => null,
            },
          ),
  ];
  num estimate(RecapLift lift) => (lift.oneRepMax?['value'] ?? lift.heaviest['weight']) as num;
  return _sorted(lifts, (a, b) => estimate(b).compareTo(estimate(a)));
}

/// The first day of every week of [period] that has begun by [now], each with
/// its workouts.
Map<DateTime, int> _weeksOf(
  RecapPeriod period,
  List<RecapWorkout> workouts, {
  required int firstWeekday,
  required DateTime now,
}) {
  final first = weekOf(period.from, firstWeekday: firstWeekday);
  final last = now.isBefore(period.to) ? now : period.to.subtract(const Duration(microseconds: 1));
  // calendar fields, not a Duration, so a DST change does not shift a week;
  // a year touches at most 54 of them
  final weeks = Iterable.generate(
    54,
    (index) => DateTime(first.year, first.month, first.day + 7 * index),
  ).takeWhile((week) => !week.isAfter(last));
  return {
    for (final week in weeks)
      week: workouts.where((workout) => weekOf(workout.start, firstWeekday: firstWeekday) == week).length,
  };
}

/// Every calendar month of [period] that has begun by [now], each with its
/// workouts.
Map<DateTime, int> _monthsOf(RecapPeriod period, List<RecapWorkout> workouts, {required DateTime now}) {
  final months = Iterable.generate(
    12,
    (index) => DateTime(period.from.year, period.from.month + index),
  ).takeWhile((month) => month.isBefore(period.to) && !month.isAfter(now));
  return {
    for (final month in months)
      month: workouts.where((workout) => (workout.start.year, workout.start.month) == (month.year, month.month)).length,
  };
}
