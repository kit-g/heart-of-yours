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

  // all seeds are derived from the Monday of the current week on the user's own
  // calendar — the anchor the queries and the aggregation both use now
  final monday = getMonday(DateTime.now());

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
    // Stored in UTC, as production does: `Workout.start` defaults to
    // `DateTime.timestamp()`. Seeding local wall-clock strings here hid a bug
    // where the queries built their boundaries in local time and compared them
    // against UTC rows — the two agree only at UTC+0.
    await db.insert('workouts', {
      'id': id,
      'start': start.toUtc().toIso8601String(),
      'end': switch ((finished, end)) {
        (false, _) => null,
        (true, DateTime e) => e.toUtc().toIso8601String(),
        (true, null) => start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
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
          // The bucketing is on the user's calendar now, so a Sunday 23:59
          // session stays in the week the user lived it — west of UTC it is
          // already Monday in UTC, which used to file it into the next week.
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
          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3), userId: userId), 0);
        },
      );

      test(
        'counts finished workouts in the week of the given date, for the asking user',
        () async {
          await seedWorkout(start: dayOf(daysFromMonday: 1, hour: 9));
          await seedWorkout(start: dayOf(daysFromMonday: 3, hour: 19));
          await seedWorkout(start: dayOf(daysFromMonday: 2), user: strangerId);
          // last week
          await seedWorkout(start: dayOf(daysFromMonday: -3));

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 4), userId: userId), 2);
          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: -3), userId: userId), 1);
        },
      );

      test(
        'excludes unfinished workouts',
        () async {
          await seedWorkout(start: dayOf(daysFromMonday: 1), finished: false);

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3), userId: userId), 0);
        },
      );

      test(
        'a null userId matches nothing',
        () async {
          // same as getWorkoutSummary: `user_id = NULL` is never true, so with
          // nobody to count for the answer is none rather than everybody's
          await seedWorkout(start: dayOf(daysFromMonday: 1));

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3)), 0);
        },
      );

      test(
        'a workout starting exactly at Monday midnight counts toward its week',
        () async {
          await seedWorkout(start: dayOf(hour: 0, minute: 0));

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3), userId: userId), 1);
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

          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 3), userId: userId), 1);
          expect(await local.getWeeklyWorkoutCount(dayOf(daysFromMonday: 10), userId: userId), 0);
        },
      );
    },
  );

  group(
    'getTotalWorkoutCount',
    () {
      test(
        'counts every finished workout, with no period bound',
        () async {
          // what a "do N workouts" milestone counts — weeks and months are
          // irrelevant to it, which is why it gets its own query
          await seedWorkout(start: dayOf(daysFromMonday: 1));
          await seedWorkout(start: dayOf(daysFromMonday: -30));
          await seedWorkout(start: dayOf(daysFromMonday: -400));

          expect(await local.getTotalWorkoutCount(userId: userId), 3);
        },
      );

      test(
        'excludes unfinished workouts and other users',
        () async {
          await seedWorkout(start: dayOf(daysFromMonday: 1));
          await seedWorkout(start: dayOf(daysFromMonday: 2), finished: false);
          await seedWorkout(start: dayOf(daysFromMonday: 3), user: strangerId);

          expect(await local.getTotalWorkoutCount(userId: userId), 1);
        },
      );

      test(
        'answers zero for a user with nothing logged',
        () async {
          expect(await local.getTotalWorkoutCount(userId: userId), 0);
        },
      );
    },
  );

  group(
    'getMonthlyWorkoutCount',
    () {
      // Anchored to fixed dates rather than to [monday]: what this query is
      // worth is entirely in where it draws month boundaries, and a seed
      // derived from "this week" straddles them differently every month.
      test(
        'counts the finished workouts inside the month',
        () async {
          await seedWorkout(start: DateTime(2026, 8, 1, 7));
          await seedWorkout(start: DateTime(2026, 8, 15, 18));
          await seedWorkout(start: DateTime(2026, 8, 31, 23));

          expect(await local.getMonthlyWorkoutCount(DateTime(2026, 8, 9), userId: userId), 3);
        },
      );

      test(
        'excludes the months either side',
        () async {
          // the ends of the range are where an off-by-one lives, and a workout
          // late on the 31st is the one a careless upper bound drops
          await seedWorkout(start: DateTime(2026, 7, 31, 23, 59));
          await seedWorkout(start: DateTime(2026, 8, 1));
          await seedWorkout(start: DateTime(2026, 8, 31, 23, 59));
          await seedWorkout(start: DateTime(2026, 9, 1));

          expect(await local.getMonthlyWorkoutCount(DateTime(2026, 8, 9), userId: userId), 2);
        },
      );

      test(
        'rolls the year over in December',
        () async {
          // the upper bound is month + 1, which is 13 here; DateTime normalises
          // it to next January, and getting that wrong counts nothing at all
          await seedWorkout(start: DateTime(2026, 12, 5));
          await seedWorkout(start: DateTime(2026, 12, 30));
          await seedWorkout(start: DateTime(2027, 1, 2));

          expect(await local.getMonthlyWorkoutCount(DateTime(2026, 12, 31), userId: userId), 2);
        },
      );

      test(
        'excludes unfinished workouts',
        () async {
          await seedWorkout(start: DateTime(2026, 8, 2));
          await seedWorkout(start: DateTime(2026, 8, 9), finished: false);

          expect(await local.getMonthlyWorkoutCount(DateTime(2026, 8, 9), userId: userId), 1);
        },
      );

      test(
        'counts only the asking user, unlike the weekly count beside it',
        () async {
          await seedWorkout(start: DateTime(2026, 8, 3));
          await seedWorkout(start: DateTime(2026, 8, 4), user: strangerId);

          expect(await local.getMonthlyWorkoutCount(DateTime(2026, 8, 9), userId: userId), 1);
        },
      );

      test(
        'a workout spanning midnight on the first counts toward the month it started in',
        () async {
          await seedWorkout(start: DateTime(2026, 7, 31, 23, 30), end: DateTime(2026, 8, 1, 1));

          expect(await local.getMonthlyWorkoutCount(DateTime(2026, 8, 9), userId: userId), 0);
          expect(await local.getMonthlyWorkoutCount(DateTime(2026, 7, 9), userId: userId), 1);
        },
      );

      test(
        'returns zero for a month with nothing in it',
        () async {
          await seedWorkout(start: DateTime(2026, 8, 3));

          expect(await local.getMonthlyWorkoutCount(DateTime(2026, 9, 9), userId: userId), 0);
        },
      );
    },
  );
}
