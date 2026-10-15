import 'package:heart_models/heart_models.dart';

/// One exercise's completed working sets in one finished workout, with what
/// the exercise is: the pattern lens's unit of data (#341,
/// `docs/2026-10-11.pattern-lens.md`).
///
/// [workoutId] says which session the sets belong to, so a key can count the
/// sessions that touched it as well as the sets. [exerciseId] is the key of a
/// goal about one exercise (#344). [target] is where an exercise nobody tagged
/// still belongs (rule 7).
typedef LensSets = ({
  String workoutId,
  String exerciseId,
  DateTime start,
  Movement movement,
  MuscleTagging muscles,
  Target target,
  int sets,
});

/// What one key gathered over one period: [sets], fractional underneath, and
/// the [sessions] that touched it at all, whole. Rule 8: counted in fractions,
/// shown in whole numbers, through [wholeSets].
typedef LensCount = ({double sets, int sessions});

/// [sets] as a screen shows them: whole, rounded down. One rounding for every
/// reader, so the weekly card and a goal on the same key never disagree, and
/// down so a muscle's 9.6 never reads "10" beside a target of 10 it has not
/// met.
int wholeSets(num sets) => sets.floor();

/// What [row]'s sets count toward under the pattern key: every pattern the
/// exercise trains, in full. A thruster is a squat and an overhead press, and
/// a set of it is a set of each; the patterns are what was moved, not shares
/// of one muscle's dose. An exercise with no movement (one the user made)
/// counts toward no pattern, and is seen by the muscle key alone.
Map<String, double> patternsOf(LensSets row) {
  return {for (final pattern in row.movement.groups) pattern: 1.0};
}

/// The first day of [date]'s week, at midnight, for a week that starts on
/// [firstWeekday] (ISO: 1 Monday … 7 Sunday). Calendar arithmetic rather than
/// a [Duration], so a week across a DST change still starts at midnight.
DateTime weekOf(DateTime date, {int firstWeekday = DateTime.monday}) {
  final back = (date.weekday - firstWeekday) % 7;
  return DateTime(date.year, date.month, date.day - back);
}

/// The first days of the [weeks] weeks ending with [now]'s, oldest first, for
/// weeks that start on [firstWeekday].
List<DateTime> lastWeeksOf(int weeks, {required DateTime now, int firstWeekday = DateTime.monday}) {
  final current = weekOf(now, firstWeekday: firstWeekday);
  return [
    for (final back in Iterable<int>.generate(weeks, (index) => weeks - 1 - index))
      DateTime(current.year, current.month, current.day - 7 * back),
  ];
}

/// [rows] counted per key into [periods], one map of keys per period.
///
/// One function for every key (rule 1): [keysOf] says what a row's sets
/// count toward and with what share, [periodOf] which period a workout's
/// start falls in — the user's week ([weekOf]), or a program's own cycle when
/// it runs on rotation (rule 2). A row whose period is not among [periods] is
/// left out; a key is present in a period only once something counted toward
/// it, and a session counts once per key however many of its exercises did.
Map<DateTime, Map<K, LensCount>> countByPeriod<K>(
  Iterable<LensSets> rows, {
  required List<DateTime> periods,
  required DateTime Function(DateTime start) periodOf,
  required Map<K, double> Function(LensSets row) keysOf,
}) {
  final sets = {for (final period in periods) period: <K, double>{}};
  final sessions = {for (final period in periods) period: <K, Set<String>>{}};
  for (final row in rows) {
    final period = periodOf(row.start);
    if ((sets[period], sessions[period]) case (final counted?, final touched?)) {
      for (final MapEntry(:key, value: share) in keysOf(row).entries.where((entry) => entry.value > 0)) {
        counted.update(key, (count) => count + row.sets * share, ifAbsent: () => row.sets * share);
        touched.putIfAbsent(key, () => {}).add(row.workoutId);
      }
    }
  }
  return {
    for (final period in periods)
      period: {
        for (final MapEntry(:key, value: count) in sets[period]!.entries)
          key: (sets: count, sessions: sessions[period]![key]!.length),
      },
  };
}

/// [rows] counted per key into the [weeks] weeks ending with [now]'s, weeks
/// starting on [firstWeekday]: [countByPeriod] over the user's own week.
Map<DateTime, Map<K, LensCount>> countByWeek<K>(
  Iterable<LensSets> rows, {
  required int weeks,
  required DateTime now,
  required Map<K, double> Function(LensSets row) keysOf,
  int firstWeekday = DateTime.monday,
}) {
  return countByPeriod(
    rows,
    periods: lastWeeksOf(weeks, now: now, firstWeekday: firstWeekday),
    periodOf: (start) => weekOf(start, firstWeekday: firstWeekday),
    keysOf: keysOf,
  );
}
