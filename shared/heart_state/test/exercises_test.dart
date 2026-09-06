import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/exercises.dart';
import 'package:heart_state/src/movement_filters.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

void main() {
  final remote = MockRemoteExerciseService();
  final local = MockExerciseService();
  final library = MockExerciseLibraryService();
  final catalog = MockLocalCatalogService();
  late Exercises sut;

  const stamp = (version: 'run-1', locale: 'en', etag: null);

  Exercises build({void Function(dynamic error, {dynamic stacktrace})? onError}) {
    return Exercises(
      remoteService: remote,
      service: local,
      libraryService: library,
      catalogService: catalog,
      onError: onError,
    );
  }

  setUp(() {
    reset(local);
    reset(library);
    reset(catalog);

    when(local.getExercises()).thenAnswer((_) async => (null, <Exercise>[]));
    when(local.storeExercises(any)).thenAnswer((_) async {});

    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    // an empty library under a fresh stamp, unless a test says otherwise
    when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) async => (<Exercise>[], stamp));
    when(catalog.getCatalogStamp()).thenAnswer((_) async => null);
    when(catalog.storeCatalog(any, stamp: anyNamed('stamp'))).thenAnswer((_) async {});

    // history/records delegates (we stub empty results)
    when(
      local.getExerciseHistory(any, any, pageSize: anyNamed('pageSize'), anchor: anyNamed('anchor')),
    ).thenAnswer((_) async => <ExerciseAct>[]);
    when(local.getRecord(any, any)).thenAnswer((_) async => null);
    when(local.getRepsHistory(any, any, limit: anyNamed('limit'))).thenAnswer((_) async => <(num, DateTime)>[]);
    when(local.getDistanceHistory(any, any, limit: anyNamed('limit'))).thenAnswer((_) async => <(num, DateTime)>[]);
    when(local.getDurationHistory(any, any, limit: anyNamed('limit'))).thenAnswer((_) async => <(num, DateTime)>[]);
    when(local.getWeightHistory(any, any, limit: anyNamed('limit'))).thenAnswer((_) async => <(num, DateTime)>[]);

    sut = build()..userId = 'u1';
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
    // the API mock lives for the whole file; count from here
    setUp(() => clearInteractions(remote));

    test('uses local exercises when available, then the CDN library and the own list (2 notifications)', () async {
      final e1 = ex('Squat');
      final e2 = ex('Deadlift');

      when(
        local.getExercises(userId: anyNamed('userId')),
      ).thenAnswer((_) async => (DateTime(2024, 1, 1), <Exercise>[e1]));
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) async => (<Exercise>[e2], stamp));

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.isInitialized, isTrue);
      expect(sut.lookup(e1.id), e1);
      expect(sut.lookup(e2.id), e2);
      expect(probe.notifications, 2); // 1 for local, 1 for the sync

      verify(local.getExercises(userId: anyNamed('userId'))).called(1);
      verify(catalog.getCatalogStamp()).called(1);
      verify(library.getLibrary(cached: null)).called(1);
      verify(catalog.storeCatalog([e2], stamp: stamp)).called(1);
      verify(remote.getOwnExercises()).called(1);
      // the API's library list is no longer read — the CDN is the catalog
      verifyNever(remote.getExercises());
    });

    test('when local is empty, the library still loads, sets initialized and notifies once', () async {
      final e1 = ex('Squat');
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) async => (<Exercise>[e1], stamp));

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.isInitialized, isTrue);
      expect(sut.lookup(e1.id), e1);
      expect(probe.notifications, 1); // 1 for the sync (none for empty local)

      // a stamp over an empty catalog is not consulted, let alone trusted
      verifyNever(catalog.getCatalogStamp());
      verify(library.getLibrary(cached: null)).called(1);
      verify(catalog.storeCatalog([e1], stamp: stamp)).called(1);
    });

    test('the catalog from the CDN and the customs from the API merge into one map by id', () async {
      final bench = ex('Bench Press');
      final curl = Exercise(name: 'My Curl', category: .dumbbell, target: .arms).copyWith(isMine: true);
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) async => (<Exercise>[bench], stamp));
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[curl]);

      await sut.init();

      expect(sut.lookup(bench.id), bench);
      expect(sut.lookup(curl.id), curl);
      expect(sut.hasOwn, isTrue);
      expect(sut.map((each) => each.id).toSet(), {bench.id, curl.id});
      // each half lands in the cache through its own door
      verify(catalog.storeCatalog([bench], stamp: stamp)).called(1);
      verify(local.storeExercises([curl], userId: 'u1')).called(1);
    });

    test('a unit preference on an own exercise is mirrored locally', () async {
      final curl = Exercise.fromJson({
        'id': 'id-curl',
        'name': 'My Curl',
        'category': 'Dumbbell',
        'target': 'Arms',
        'own': true,
        'unit_system': 'imperial',
      });
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[curl]);

      await sut.init();

      expect(sut.unitFor(curl.id), MeasurementUnit.imperial);
      verify(local.setExerciseUnit(exerciseName: curl.id, userId: 'u1', unit: MeasurementUnit.imperial)).called(1);
    });

    test('a CDN failure with a warm cache is survivable', () async {
      final e1 = ex('Squat');
      Object? err;
      sut = build(onError: (e, {stacktrace}) => err = e);
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (DateTime(2024), <Exercise>[e1]));
      when(library.getLibrary(cached: anyNamed('cached'))).thenThrow(Exception('cdn down'));

      expect(await sut.init(), isTrue);

      expect(sut.isInitialized, isTrue);
      expect(sut.lookup(e1.id), e1);
      expect(err, isNotNull);
    });

    test('a CDN failure with a cold cache surfaces the error path', () async {
      Object? err;
      sut = build(onError: (e, {stacktrace}) => err = e);
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(library.getLibrary(cached: anyNamed('cached'))).thenThrow(Exception('cdn down'));

      expect(await sut.init(), isFalse);

      expect(sut.isInitialized, isFalse);
      expect(sut, isEmpty);
      expect(err, isNotNull);
      verifyNever(remote.getOwnExercises());
    });

    test('a current library is not re-stored; a moved stamp is', () async {
      const moved = (version: 'run-2', locale: 'en', etag: null);
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (DateTime(2024), [ex('Squat')]));
      when(catalog.getCatalogStamp()).thenAnswer((_) async => stamp);
      when(library.getLibrary(cached: stamp)).thenAnswer((_) async => (null, stamp));

      await sut.init(locale: 'en');

      verifyNever(catalog.storeCatalog(any, stamp: anyNamed('stamp')));

      when(library.getLibrary(cached: stamp)).thenAnswer((_) async => (null, moved));
      await sut.onLocaleChanged('en-CA');

      verify(catalog.storeCatalog(<Exercise>[], stamp: moved)).called(1);
    });

    test('a cache holding only customs does not vouch for a library', () async {
      final mine = ex('My Thing').copyWith(isMine: true);
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (DateTime(2024), [mine]));
      when(catalog.getCatalogStamp()).thenAnswer((_) async => stamp);

      await sut.init();

      verifyNever(catalog.getCatalogStamp());
      verify(library.getLibrary(cached: null)).called(1);
    });

    test('routes errors to onError and does not throw', () async {
      Object? err;
      sut = build(onError: (e, {stacktrace}) => err = e);
      when(local.getExercises()).thenThrow(Exception('boom'));

      await sut.init(lastSync: DateTime(2020, 1, 1));

      expect(err, isNotNull);
    });
  });

  group('onLocaleChanged()', () {
    // The library is published per locale; `id` is the identity that survives
    // it. A locale change must overwrite display copy in place, never fork
    // the entry.
    test('re-fetches the library and overwrites display copy under the same identity', () async {
      final en = ex('Bench Press');
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) async => (<Exercise>[en], stamp));
      await sut.init(locale: 'en');
      expect(sut.lookup(en.id)?.name, 'Bench Press');
      clearInteractions(remote);

      final ru = Exercise.fromJson({
        'id': en.id,
        'name': 'Жим лёжа',
        'category': 'Weighted Body Weight',
        'target': 'Chest',
      });
      const inRussian = (version: 'run-1', locale: 'ru', etag: null);
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) async => (<Exercise>[ru], inRussian));

      await sut.onLocaleChanged('ru');

      expect(sut.lookup(en.id)?.name, 'Жим лёжа');
      expect(sut.where((each) => each.id == en.id), hasLength(1));
      verify(catalog.storeCatalog([ru], stamp: inRussian)).called(1);
      // customs are not localized, so the API has no part in this
      verifyNever(remote.getOwnExercises());
    });

    test('the same tag again is a no-op', () async {
      final en = ex('Bench Press');
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) async => (<Exercise>[en], stamp));
      await sut.init(locale: 'en');

      // were a fetch to happen, this copy would show up
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer(
        (_) async => (
          <Exercise>[
            Exercise.fromJson({
              'id': en.id,
              'name': 'Жим лёжа',
              'category': 'Weighted Body Weight',
              'target': 'Chest',
            }),
          ],
          stamp,
        ),
      );

      await sut.onLocaleChanged('en');

      expect(sut.lookup(en.id)?.name, 'Bench Press');
    });

    test('a change before init is only recorded — init fetches under the new header anyway', () async {
      await sut.onLocaleChanged('ru');

      expect(sut.isInitialized, isFalse);
      expect(sut, isEmpty);
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
        'id': 'id-treadmill',
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
        final own = Exercise(
          name: 'Bench Press',
          category: Category.barbell,
          target: Target.chest,
        ).copyWith(isMine: true);
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
      final own = Exercise(
        name: 'Bench Press',
        category: Category.barbell,
        target: Target.chest,
      ).copyWith(isMine: true);
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
      final ownChest = Exercise(
        name: 'Bench Press',
        category: Category.barbell,
        target: Target.chest,
      ).copyWith(isMine: true);
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
      when(
        local.getExerciseMetics('u1', ChartPreferenceType.totalVolume, 'Bench', limit: 8),
      ).thenAnswer((_) async => metrics);

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

  group('alternativesTo()', () {
    Future<void> load(List<Exercise> exercises) async {
      when(
        local.getExercises(userId: anyNamed('userId')),
      ).thenAnswer((_) async => (null, exercises));
      await sut.init(lastSync: DateTime(2000));
    }

    test('offers everyone else in the group and never the exercise itself', () async {
      final squat = ex('Squat', movement: movement(['squat_bilateral']));
      await load([
        squat,
        ex('Hack Squat', movement: movement(['squat_bilateral'])),
        ex('Bench Press', movement: movement(['horizontal_press'])),
      ]);

      expect(sut.alternativesTo(squat).map((e) => e.name), ['Hack Squat']);
    });

    test('is empty for an unannotated exercise', () async {
      final mine = ex('My Curl');
      await load([
        mine,
        ex('Hack Squat', movement: movement(['squat_bilateral'])),
      ]);

      expect(sut.alternativesTo(mine), isEmpty);
    });

    test('never offers an unannotated exercise as a substitute', () async {
      final squat = ex('Squat', movement: movement(['squat_bilateral']));
      await load([squat, ex('My Squat Thing')]);

      expect(sut.alternativesTo(squat), isEmpty);
    });

    test('ranks nearer load attributes first', () async {
      // distance from the barbell squat: goblet 1 (axial), hack 2 (axial +
      // stability), leg press 3 (axial x2 + stability).
      final squat = ex('Squat', movement: movement(['squat_bilateral'], axialLoad: 'high'));
      await load([
        squat,
        ex(
          'Leg Press',
          movement: movement(['squat_bilateral'], axialLoad: 'low', stability: 'machine'),
        ),
        ex(
          'Hack Squat',
          movement: movement(['squat_bilateral'], axialLoad: 'moderate', stability: 'machine'),
        ),
        ex('Goblet Squat', movement: movement(['squat_bilateral'], axialLoad: 'moderate')),
      ]);

      expect(
        sut.alternativesTo(squat).map((e) => e.name),
        ['Goblet Squat', 'Hack Squat', 'Leg Press'],
      );
    });

    test('breaks ties by name so the order is stable', () async {
      final squat = ex('Squat', movement: movement(['squat_bilateral']));
      await load([
        squat,
        ex('Zercher Squat', movement: movement(['squat_bilateral'])),
        ex('Front Squat', movement: movement(['squat_bilateral'])),
      ]);

      expect(sut.alternativesTo(squat).map((e) => e.name), ['Front Squat', 'Zercher Squat']);
    });

    test('matches on any shared group, not just the first', () async {
      final thruster = ex('Thruster', movement: movement(['squat_bilateral', 'vertical_press']));
      await load([
        thruster,
        ex('Overhead Press', movement: movement(['vertical_press'])),
      ]);

      expect(sut.alternativesTo(thruster).map((e) => e.name), ['Overhead Press']);
    });

    test('excludes archived exercises', () async {
      final squat = ex('Squat', movement: movement(['squat_bilateral']));
      await load([
        squat,
        ex('Hack Squat', movement: movement(['squat_bilateral']), archived: true),
      ]);

      expect(sut.alternativesTo(squat), isEmpty);
    });

    test('resolves the annotated library copy from an unannotated stub', () async {
      // workout and template payloads embed a stub with no movement
      await load([
        ex('Squat', movement: movement(['squat_bilateral'])),
        ex('Hack Squat', movement: movement(['squat_bilateral'])),
      ]);

      expect(sut.alternativesTo(ex('Squat')).map((e) => e.name), ['Hack Squat']);
    });
  });

  group('movement filters in search()', () {
    Future<void> load(List<Exercise> exercises) async {
      when(
        local.getExercises(userId: anyNamed('userId')),
      ).thenAnswer((_) async => (null, exercises));
      await sut.init(lastSync: DateTime(2000));
    }

    test('narrows the library to a movement pattern', () async {
      await load([
        ex('Bench Press', movement: movement(['horizontal_press'])),
        ex('Squat', movement: movement(['squat_bilateral'])),
      ]);
      sut.addFilter(const PatternFilter('horizontal_press'));

      expect(sut.search('', filters: true).map((e) => e.name), ['Bench Press']);
    });

    test('composes with category and target rather than replacing them', () async {
      // `fits` handles these two and passes the movement filter; the movement
      // predicate does the reverse. Both have to hold.
      await load([
        ex('Bench Press', movement: movement(['horizontal_press'])),
        ex('Push Up', movement: movement(['horizontal_press'])),
      ]);
      sut
        ..addFilter(const PatternFilter('horizontal_press'))
        ..addFilter(Target.legs);

      expect(sut.search('', filters: true), isEmpty);
    });

    test('does nothing when the caller opts out of filtering', () async {
      await load([
        ex('Squat', movement: movement(['squat_bilateral'])),
      ]);
      sut.addFilter(const PatternFilter('horizontal_press'));

      expect(sut.search('').map((e) => e.name), ['Squat']);
    });

    test('hides user-created exercises, which carry no annotation', () async {
      await load([
        ex('Bench Press', movement: movement(['horizontal_press'])),
        ex('My Curl'),
      ]);
      sut.addFilter(const SkillCeiling(SkillLevel.high));

      expect(sut.search('', filters: true).map((e) => e.name), ['Bench Press']);
    });
  });

  group('patterns', () {
    Future<void> load(List<Exercise> exercises) async {
      when(
        local.getExercises(userId: anyNamed('userId')),
      ).thenAnswer((_) async => (null, exercises));
      await sut.init(lastSync: DateTime(2000));
    }

    test('lists what the library uses, most common first', () async {
      await load([
        ex('Bench Press', movement: movement(['horizontal_press'])),
        ex('Push Up', movement: movement(['horizontal_press'])),
        ex('Squat', movement: movement(['squat_bilateral'])),
      ]);

      expect(sut.patterns, ['horizontal_press', 'squat_bilateral']);
    });

    test('breaks count ties alphabetically so the order is stable', () async {
      await load([
        ex('Squat', movement: movement(['squat_bilateral'])),
        ex('Bench Press', movement: movement(['horizontal_press'])),
      ]);

      expect(sut.patterns, ['horizontal_press', 'squat_bilateral']);
    });

    test('counts every group of a multi-pattern exercise', () async {
      await load([
        ex('Lunge', movement: movement(['squat_unilateral', 'lunge'])),
      ]);

      expect(sut.patterns, containsAll(['lunge', 'squat_unilateral']));
    });

    test('ignores archived exercises, which the picker never shows', () async {
      await load([
        ex('Bench Press', movement: movement(['horizontal_press'])),
        ex('Sissy Squat', movement: movement(['squat_bilateral']), archived: true),
      ]);

      expect(sut.patterns, ['horizontal_press']);
    });
  });
}
