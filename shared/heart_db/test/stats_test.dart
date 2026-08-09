import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';
  const strangerId = 'user-2';

  // all seeds are derived from the Monday of the current week — the same
  // anchor the queries themselves compute from DateTime.timestamp()
  final monday = getMonday(DateTime.timestamp());

  // calendar arithmetic (not Duration) so day offsets survive DST shifts
  DateTime dayOf({int daysFromMonday = 0, int hour = 12, int minute = 0}) {
    return DateTime(monday.year, monday.month, monday.day + daysFromMonday, hour, minute);
  }

  var sequence = 0;

  Future<String> seedWorkout({
    required DateTime start,
    bool finished = true,
    DateTime? end,
    String user = userId,
    String? name,
  }) async {
    final id = 'workout-${sequence++}';
    await db.insert('workouts', {
      'id': id,
      'start': start.toIso8601String(),
      'end': switch ((finished, end)) {
        (false, _) => null,
        (true, DateTime e) => e.toIso8601String(),
        (true, null) => start.add(const Duration(hours: 1)).toIso8601String(),
      },
      'user_id': user,
      'name': name,
    });
    return id;
  }

  Map<DateTime, int> nonEmptyWeeks(WorkoutAggregation aggregation) {
    return {
      for (final week in aggregation)
        if (week.isNotEmpty) week.startDate: week.length,
    };
  }

  setUp(
    () async {
      db = await openTestDatabase();
      local = await LocalDatabase.init(other: db);
    },
  );

  tearDown(
    () async {
      await db.close();
    },
  );

  group(
    'getWorkoutSummary',
    () {
      test(
        'returns the empty aggregation when nothing is stored',
        () async {
          final result = await local.getWorkoutSummary(userId: userId);

          expect(result.isEmpty, isTrue);
          expect(result.max, 0);
        },
      );

      test(
        'ignores unfinished workouts',
        () async {
          await seedWorkout(start: dayOf(daysFromMonday: 1), finished: false);

          final result = await local.getWorkoutSummary(userId: userId);

          expect(result.isEmpty, isTrue);
        },
      );

      test(
        'ignores other users\' workouts',
        () async {
          await seedWorkout(start: dayOf(daysFromMonday: 1), user: strangerId);

          final result = await local.getWorkoutSummary(userId: userId);

          expect(result.isEmpty, isTrue);
        },
      );

      test(
        'a null userId matches nothing',
        () async {
          // without a userId there is no one to aggregate for: the call
          // answers empty without touching the database
          await seedWorkout(start: dayOf(daysFromMonday: 1));

          final result = await local.getWorkoutSummary();

          expect(result.isEmpty, isTrue);
        },
      );

      test(
        'groups workouts into their weeks and surfaces ids and names',
        () async {
          final tuesday = await seedWorkout(start: dayOf(daysFromMonday: 1, hour: 10), name: 'Push');
          final wednesday = await seedWorkout(start: dayOf(daysFromMonday: 2, hour: 18), name: 'Pull');
          await seedWorkout(start: dayOf(daysFromMonday: -4), name: 'Legs');

          final result = await local.getWorkoutSummary(userId: userId);

          expect(
            nonEmptyWeeks(result),
            {
              monday: 2,
              getMonday(dayOf(daysFromMonday: -4)): 1,
            },
          );
          expect(result.max, 2);

          // weeks come back sorted ascending, so the current week is last
          final current = result.last;

          expect(current.map((each) => each.id), containsAll([tuesday, wednesday]));
          expect(current.map((each) => each.name), containsAll(['Push', 'Pull']));
        },
      );

      test(
        'Sunday night and Monday morning land in adjacent weeks',
        () async {
          final sundayNight = dayOf(daysFromMonday: -1, hour: 23, minute: 59);
          await seedWorkout(start: sundayNight);
          final mondayId = await seedWorkout(start: dayOf(hour: 0, minute: 30));

          final result = await local.getWorkoutSummary(userId: userId);

          expect(
            nonEmptyWeeks(result),
            {
              monday: 1,
              getMonday(sundayNight): 1,
            },
          );
          expect(result.last.map((each) => each.id), [mondayId]);
        },
      );

      test(
        'a workout spanning midnight counts toward the week it started in',
        () async {
          final start = dayOf(daysFromMonday: -1, hour: 23, minute: 30);
          await seedWorkout(start: start, end: dayOf(hour: 1));

          final result = await local.getWorkoutSummary(userId: userId);
          final weeks = nonEmptyWeeks(result);

          expect(weeks, {getMonday(start): 1});
          expect(weeks.keys.single, isNot(monday));
        },
      );

      test(
        'weeksBack limits how far back the summary reaches',
        () async {
          await seedWorkout(start: dayOf(daysFromMonday: 1));
          // three weeks back
          await seedWorkout(start: dayOf(daysFromMonday: -19));

          final narrow = await local.getWorkoutSummary(weeksBack: 2, userId: userId);
          final wide = await local.getWorkoutSummary(userId: userId);

          expect(nonEmptyWeeks(narrow), {monday: 1});
          expect(
            nonEmptyWeeks(wide),
            {
              monday: 1,
              getMonday(dayOf(daysFromMonday: -19)): 1,
            },
          );
        },
      );

      test(
        'a workout starting exactly at the cutoff is included',
        () async {
          // with weeksBack: 0 the cutoff is this Monday 00:00; a workout
          // starting at that very moment belongs to the window
          final atCutoff = await seedWorkout(start: dayOf(hour: 0, minute: 0));
          final later = await seedWorkout(start: dayOf(daysFromMonday: 1));

          final result = await local.getWorkoutSummary(weeksBack: 0, userId: userId);

          expect(result.max, 2);
          expect(result.last.map((each) => each.id), containsAll([atCutoff, later]));
        },
      );
    },
  );

  group(
    'getWeeklyWorkoutCount',
    () {
      test(
        'returns zero for an empty week',
        () async {
          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3)), 0);
        },
      );

      test(
        'counts finished workouts in the week of the given date, for every user',
        () async {
          await seedWorkout(start: dayOf(daysFromMonday: 1, hour: 9));
          await seedWorkout(start: dayOf(daysFromMonday: 3, hour: 19));
          // the query carries no user filter, so other users on the device
          // count too — documents current behavior
          await seedWorkout(start: dayOf(daysFromMonday: 2), user: strangerId);
          // last week
          await seedWorkout(start: dayOf(daysFromMonday: -3));

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 4)), 3);
          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: -3)), 1);
        },
      );

      test(
        'excludes unfinished workouts',
        () async {
          await seedWorkout(start: dayOf(daysFromMonday: 1), finished: false);

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3)), 0);
        },
      );

      test(
        'a workout starting exactly at Monday midnight counts toward its week',
        () async {
          await seedWorkout(start: dayOf(hour: 0, minute: 0));

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3)), 1);
        },
      );

      test(
        'a workout spanning the week boundary counts toward the week it started in',
        () async {
          // starts Sunday 23:00, ends Monday 01:00 of the next week: a workout
          // belongs to the week of its start, and only that week
          await seedWorkout(
            start: dayOf(daysFromMonday: 6, hour: 23),
            end: dayOf(daysFromMonday: 7, hour: 1),
          );

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3)), 1);
          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 10)), 0);
        },
      );
    },
  );
}
