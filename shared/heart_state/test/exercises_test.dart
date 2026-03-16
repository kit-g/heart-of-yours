import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/exercises.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

void main() {
  final remote = MockRemoteExerciseService();
  final local = MockExerciseService();
  late Exercises sut;

  setUp(() {
    reset(local);

    when(local.getExercises()).thenAnswer((_) async => (null, <Exercise>[]));
    when(local.storeExercises(any)).thenAnswer((_) async {});

    when(remote.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    // history/records delegates (we stub empty results)
    when(local.getExerciseHistory(any, any, pageSize: anyNamed('pageSize'), anchor: anyNamed('anchor')))
        .thenAnswer((_) async => <ExerciseAct>[]);
    when(local.getRecord(any, any)).thenAnswer((_) async => null);
    when(local.getRepsHistory(any, any, limit: anyNamed('limit'))).thenAnswer((_) async => <(num, DateTime)>[]);
    when(local.getDistanceHistory(any, any, limit: anyNamed('limit'))).thenAnswer((_) async => <(num, DateTime)>[]);
    when(local.getDurationHistory(any, any, limit: anyNamed('limit'))).thenAnswer((_) async => <(num, DateTime)>[]);
    when(local.getWeightHistory(any, any, limit: anyNamed('limit'))).thenAnswer((_) async => <(num, DateTime)>[]);

    sut = Exercises(remoteService: remote, service: local)..userId = 'u1';
  });

  group('Provider helpers', () {
    testWidgets('of(context) returns the provided instance', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sut,
          child: Builder(
            builder: (context) {
              final got = Exercises.of(context);
              expect(identical(got, sut), isTrue);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('watch(context) rebuilds on notifyListeners', (tester) async {
      int builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sut,
          child: Builder(
            builder: (context) {
              // watch triggers rebuild when sut notifies
              final _ = Exercises.watch(context).isInitialized;
              builds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(builds, 1);

      // trigger a notify by selecting an exercise
      final e = ex('Bench Press');
      sut.select(e);
      await tester.pump();
      expect(builds, 2);
    });
  });

  group('init()', () {
    test('uses local exercises when available, then fetches remote (2 notifications total)', () async {
      final e1 = ex('Squat');
      final e2 = ex('Deadlift');

      when(local.getExercises(userId: anyNamed('userId')))
          .thenAnswer((_) async => (DateTime(2024, 1, 1), <Exercise>[e1]));
      when(remote.getExercises()).thenAnswer((_) async => <Exercise>[e2]);
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.isInitialized, isTrue);
      expect(sut.lookup(e1.name), e1);
      expect(sut.lookup(e2.name), e2);
      expect(probe.notifications, 2); // 1 for local, 1 for remote

      verify(local.getExercises(userId: anyNamed('userId'))).called(1);
      verify(remote.getExercises()).called(1);
      verify(remote.getOwnExercises()).called(1);
      verify(local.storeExercises(any, userId: anyNamed('userId'))).called(1);
    });

    test('when local is empty, still fetches remote, sets initialized and notifies once', () async {
      final e1 = ex('Squat');
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(remote.getExercises()).thenAnswer((_) async => <Exercise>[e1]);
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.isInitialized, isTrue);
      expect(sut.lookup(e1.name), e1);
      expect(probe.notifications, 1); // 1 for remote (none for empty local)

      verify(remote.getExercises()).called(1);
      verify(local.storeExercises(any, userId: anyNamed('userId'))).called(1);
    });

    test('routes errors to onError and does not throw', () async {
      Object? err;
      sut = Exercises(remoteService: remote, service: local, onError: (e, {stacktrace}) => err = e);
      when(local.getExercises()).thenThrow(Exception('boom'));

      await sut.init(lastSync: DateTime(2020, 1, 1));

      expect(err, isNotNull);
    });
  });

  group('search()', () {
    test('matches words in name ignoring order/case', () async {
      final e = ex('Incline Bench Press');
      when(
        local.getExercises(userId: anyNamed('userId')),
      ).thenAnswer((_) async => (null, <Exercise>[e]));
      await sut.init(lastSync: DateTime(2000));

      expect(sut.search('bench').toList(), contains(e));
      expect(sut.search('incline press').toList(), contains(e));
      expect(sut.search('  PRESS  ').toList(), contains(e));
      expect(sut.search('squat').toList(), isEmpty);
    });

    test('applies filters when filters=true', () async {
      final a = ex('Bench Press');
      final b = Exercise.fromJson({
        'name': 'Treadmill',
        'category': 'Cardio',
        'target': 'Cardio',
        'asset': null,
        'thumbnail': null,
        'instructions': null,
      });

      when(
        local.getExercises(userId: anyNamed('userId')),
      ).thenAnswer(
        (_) async => (null, <Exercise>[a, b]),
      );
      await sut.init(lastSync: DateTime(2000));

      sut.addFilter(Category.weightedBodyWeight);
      sut.addFilter(Target.chest);

      final filtered = sut.search('press', filters: true).toList();
      expect(filtered, [a]);

      // without filters flag, both would match by name query (if query matches)
      final all = sut.search('press', filters: false).toList();
      expect(all, [a]);
    });
  });

  group('search() ownership filter (isMine)', () {
    test(
      'when isMine=false (default), returns both own and non-own (if they match query)',
      () async {
        final own =
            Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest).copyWith(isMine: true);
        final publicEx = Exercise(name: 'Bench Press Wide', category: Category.barbell, target: Target.chest);
        when(
          local.getExercises(
            userId: anyNamed('userId'),
          ),
        ).thenAnswer(
          (_) async => (null, <Exercise>[own, publicEx]),
        );
        await sut.init(lastSync: DateTime(2000));

        final result = sut.search('bench').toList();
        expect(result, containsAll([own, publicEx]));
      },
    );

    test('when isMine=true, returns only exercises where isMine == true', () async {
      final own =
          Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest).copyWith(isMine: true);
      final publicEx = Exercise(name: 'Bench Press Wide', category: Category.barbell, target: Target.chest);
      when(
        local.getExercises(
          userId: anyNamed('userId'),
        ),
      ).thenAnswer(
        (_) async => (
          null,
          <Exercise>[own, publicEx],
        ),
      );
      await sut.init(lastSync: DateTime(2000));

      final result = sut.search('bench', isMine: true).toList();
      expect(result, [own]);
    });

    test('isMine=true still respects query and filters', () async {
      final ownChest =
          Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest).copyWith(isMine: true);
      final ownBack = Exercise(name: 'Row', category: Category.barbell, target: Target.back).copyWith(isMine: true);
      final publicChest = Exercise(name: 'Incline Bench Press', category: Category.barbell, target: Target.chest);

      when(
        local.getExercises(
          userId: anyNamed('userId'),
        ),
      ).thenAnswer(
        (_) async => (
          null,
          <Exercise>[ownChest, ownBack, publicChest],
        ),
      );
      await sut.init(lastSync: DateTime(2000));

      // query narrows to "bench"
      final q = sut.search('bench', isMine: true).toList();
      expect(q, [ownChest], reason: 'Only own + matching query');

      // with filters=true, also enforce category/target filters
      sut.clearFilters();
      sut.addFilter(Category.barbell);
      sut.addFilter(Target.chest);

      final qf = sut.search('bench', filters: true, isMine: true).toList();
      expect(qf, [ownChest]);

      // if filters exclude chest, nothing should pass even if own
      sut.clearFilters();
      sut.addFilter(Target.back);
      final excluded = sut.search('bench', filters: true, isMine: true).toList();
      expect(excluded, isEmpty);
    });

    test('archived are excluded regardless of isMine', () async {
      final ownArchived = Exercise(
        name: 'Bench Press',
        category: Category.barbell,
        target: Target.chest,
      ).copyWith(isMine: true, isArchived: true);

      final ownActive = Exercise(
        name: 'Bench Press Narrow',
        category: Category.barbell,
        target: Target.chest,
      ).copyWith(isMine: true);

      when(
        local.getExercises(
          userId: anyNamed('userId'),
        ),
      ).thenAnswer(
        (_) async => (
          null,
          <Exercise>[ownArchived, ownActive],
        ),
      );

      await sut.init(lastSync: DateTime(2000));

      final result = sut.search('bench', isMine: true).toList();
      expect(result, [ownActive]);
    });

    test('isMine=true with empty query still filters by ownership', () async {
      final own = Exercise(name: 'A', category: Category.cardio, target: Target.cardio).copyWith(isMine: true);
      final publicEx = Exercise(name: 'B', category: Category.cardio, target: Target.cardio);
      when(
        local.getExercises(
          userId: anyNamed('userId'),
        ),
      ).thenAnswer(
        (_) async => (null, <Exercise>[own, publicEx]),
      );
      await sut.init(lastSync: DateTime(2000));

      final result = sut.search('', isMine: true).toList();
      expect(result, [own]);
    });
  });

  group('selection', () {
    test('select/deselect/unselectAll with notifications and hasSelected', () async {
      final probe = ListenerProbe()..attach(sut);
      final e1 = ex('Curl');
      final e2 = ex('Row');

      sut.select(e1);
      sut.select(e2);
      expect(probe.notifications, 2);
      expect(sut.hasSelected(e1), isTrue);
      expect(sut.selected.toSet(), {e1, e2});

      sut.deselect(e1);
      expect(probe.notifications, 3);
      expect(sut.hasSelected(e1), isFalse);

      sut.unselectAll();
      expect(probe.notifications, 4);
      expect(sut.selected, isEmpty);
    });
  });

  group('filters', () {
    test('add/remove/clear and categories/targets views', () async {
      final probe = ListenerProbe()..attach(sut);
      sut.addFilter(Category.dumbbell);
      sut.addFilter(Target.arms);
      expect(probe.notifications, 2);

      expect(sut.filters.toSet(), {Category.dumbbell, Target.arms});
      expect(sut.categories.toList(), [Category.dumbbell]);
      expect(sut.targets.toList(), [Target.arms]);

      sut.removeFilter(Target.arms);
      expect(probe.notifications, 3);
      expect(sut.targets, isEmpty);

      sut.clearFilters();
      expect(probe.notifications, 4);
      expect(sut.filters, isEmpty);
    });
  });

  group('delegations with userId', () {
    test('history and records delegate to service when userId is set', () async {
      final e = ex('Bench');

      await sut.getExerciseHistory(e, pageSize: 20, anchor: 'a1');
      verify(local.getExerciseHistory('u1', e, pageSize: 20, anchor: 'a1')).called(1);

      await sut.getExerciseRecords(e);
      verify(local.getRecord('u1', e)).called(1);

      await sut.getRepsHistory(e);
      verify(local.getRepsHistory('u1', e, limit: 30)).called(1);

      await sut.getDistanceHistory(e);
      verify(local.getDistanceHistory('u1', e, limit: 30)).called(1);

      await sut.getDurationHistory(e);
      verify(local.getDurationHistory('u1', e, limit: 30)).called(1);

      await sut.getWeightHistory(e);
      verify(local.getWeightHistory('u1', e, limit: 30)).called(1);
    });

    test('returns empty/null when userId is null', () async {
      sut.userId = null;
      final e = ex('Bench');

      final hist = await sut.getExerciseHistory(e);
      expect(hist, isEmpty);
      final rec = await sut.getExerciseRecords(e);
      expect(rec, isNull);
      expect(await sut.getRepsHistory(e), isNull);
      expect(await sut.getDistanceHistory(e), isNull);
      expect(await sut.getDurationHistory(e), isNull);
      expect(await sut.getWeightHistory(e), isNull);
      expect(await sut.getChartExerciseMetics(ChartPreferenceType.totalVolume, 'Bench'), isNull);

      verifyZeroInteractions(local);
    });

    test('getChartExerciseMetics delegates to service when userId is set', () async {
      final metrics = <(num, DateTime)>[(100.0, DateTime(2024, 1, 1))];
      when(local.getExerciseMetics('u1', ChartPreferenceType.totalVolume, 'Bench', limit: 8))
          .thenAnswer((_) async => metrics);

      final result = await sut.getChartExerciseMetics(ChartPreferenceType.totalVolume, 'Bench');

      expect(result, metrics);
      verify(local.getExerciseMetics('u1', ChartPreferenceType.totalVolume, 'Bench', limit: 8)).called(1);
    });
  });

  group('showingMine', () {
    test('getter/setter works and notifies', () {
      final probe = ListenerProbe()..attach(sut);
      expect(sut.showingMine, isFalse);

      sut.showingMine = true;
      expect(sut.showingMine, isTrue);
      expect(probe.notifications, 1);

      sut.showingMine = false;
      expect(sut.showingMine, isFalse);
      expect(probe.notifications, 2);
    });
  });

  group('misc', () {
    test('iterator, index operator, and sign-out does not notify', () async {
      when(
        local.getExercises(userId: anyNamed('userId')),
      ).thenAnswer(
        (_) async => (null, <Exercise>[ex('A'), ex('B')]),
      );
      await sut.init(lastSync: DateTime(2000));

      // iterator and []
      expect(sut.map((e) => e.name).toList(), ['A', 'B']);
      expect(sut[0].name, 'A');

      final probe = ListenerProbe()..attach(sut);
      sut.onSignOut();
      expect(probe.notifications, 0);
      expect(sut.isInitialized, isFalse);
      expect(sut.selected, isEmpty);
      expect(sut.filters, isEmpty);
    });
  });
}
