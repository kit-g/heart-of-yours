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
    'getPreferences',
    () {
      test(
        'returns nothing for a user with no preferences',
        () async {
          expect(await local.getPreferences(userId), isEmpty);
        },
      );

      test(
        'round-trips a saved exercise preference',
        () async {
          final saved = await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );

          expect(saved.id, isNotNull);

          final stored = (await local.getPreferences(userId)).single;

          expect(stored.id, saved.id);
          expect(stored.type, ChartPreferenceType.topSetWeight);
          expect(stored.exerciseName, 'Push Up');
          expect(stored.data, {'exerciseName': 'Push Up'});
        },
      );

      test(
        'round-trips a preference without data',
        () async {
          await local.saveChartPreference(
            ChartPreference.create(type: .totalVolume),
            userId,
          );

          final stored = (await local.getPreferences(userId)).single;

          expect(stored.type, ChartPreferenceType.totalVolume);
          expect(stored.data, isNull);
          expect(stored.exerciseName, isNull);
        },
      );

      test(
        'keeps preferences in insertion order',
        () async {
          final first = await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );
          final second = await local.saveChartPreference(
            ChartPreference.exercise('Squat', .totalReps),
            userId,
          );
          final third = await local.saveChartPreference(
            ChartPreference.exercise('Jog', .cardioDistance),
            userId,
          );

          final ids = (await local.getPreferences(userId)).map((each) => each.id);

          expect(ids, [first.id, second.id, third.id]);
        },
      );

      test(
        'only returns the addressed user\'s preferences',
        () async {
          await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );
          await local.saveChartPreference(
            ChartPreference.exercise('Squat', .totalReps),
            strangerId,
          );

          final mine = (await local.getPreferences(userId)).single;
          final theirs = (await local.getPreferences(strangerId)).single;

          expect(mine.exerciseName, 'Push Up');
          expect(theirs.exerciseName, 'Squat');
        },
      );
    },
  );

  group(
    'saveChartPreference',
    () {
      test(
        're-saving the same exercise chart replaces it and moves it last',
        () async {
          final original = await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );
          final other = await local.saveChartPreference(
            ChartPreference.exercise('Squat', .totalReps),
            userId,
          );
          final replacement = await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );

          final prefs = (await local.getPreferences(userId)).toList();

          // the unique (user_id, type, data) index plus the REPLACE insert
          // collapse the duplicate into a fresh row at the end of the list
          expect(prefs, hasLength(2));
          expect(prefs.map((each) => each.id), [other.id, replacement.id]);
          expect(replacement.id, isNot(original.id));
        },
      );

      test(
        'data-less duplicates are not collapsed',
        () async {
          // charts_unique_idx covers ifnull(data, ''), so re-saving the same
          // account-wide (data-less) chart replaces rather than duplicates
          await local.saveChartPreference(
            ChartPreference.create(type: .totalVolume),
            userId,
          );
          await local.saveChartPreference(
            ChartPreference.create(type: .totalVolume),
            userId,
          );

          expect(await local.getPreferences(userId), hasLength(1));
        },
      );
    },
  );

  group(
    'saveChartOrder',
    () {
      test(
        'rearranges the user\'s preferences',
        () async {
          final first = await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );
          final second = await local.saveChartPreference(
            ChartPreference.exercise('Squat', .totalReps),
            userId,
          );
          final third = await local.saveChartPreference(
            ChartPreference.exercise('Jog', .cardioDistance),
            userId,
          );

          await local.saveChartOrder([third.id!, first.id!, second.id!], userId);

          final ids = (await local.getPreferences(userId)).map((each) => each.id);

          expect(ids, [third.id, first.id, second.id]);
        },
      );

      test(
        'ignores rows that belong to another user',
        () async {
          final first = await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );
          final second = await local.saveChartPreference(
            ChartPreference.exercise('Squat', .totalReps),
            userId,
          );

          await local.saveChartOrder([second.id!, first.id!], strangerId);

          final ids = (await local.getPreferences(userId)).map((each) => each.id);

          expect(ids, [first.id, second.id]);
        },
      );
    },
  );

  group(
    'deleteChartPreference',
    () {
      test(
        'removes only the addressed preference',
        () async {
          final doomed = await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );
          final kept = await local.saveChartPreference(
            ChartPreference.exercise('Squat', .totalReps),
            userId,
          );

          await local.deleteChartPreference(doomed.id!, userId);

          final remaining = (await local.getPreferences(userId)).single;

          expect(remaining.id, kept.id);
        },
      );

      test(
        'does nothing when the preference belongs to another user',
        () async {
          final saved = await local.saveChartPreference(
            ChartPreference.exercise('Push Up', .topSetWeight),
            userId,
          );

          await local.deleteChartPreference(saved.id!, strangerId);

          expect(await local.getPreferences(userId), hasLength(1));
        },
      );
    },
  );
}
