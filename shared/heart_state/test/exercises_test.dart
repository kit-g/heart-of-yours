import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/exercises.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';
import 'note_service_fake.dart';

import 'package:heart_state/src/remote.dart';

void main() {
  final remote = MockRemoteExerciseService();
  final local = MockExerciseService();
  final library = MockExerciseLibraryService();
  final catalog = MockLocalCatalogService();
  final preferences = MockRemoteExercisePreferenceService();

  /// What [Exercises] hands `Timers`, keyed by exercise id.
  final notes = NoteStore();
  final access = RemoteAccess();
  final timers = <String, int>{};
  late Exercises sut;

  const stamp = (version: 'run-1', locale: 'en', etag: null);

  Exercises build({
    void Function(dynamic error, {dynamic stacktrace})? onError,
    Duration libraryWait = const Duration(seconds: 30),
  }) {
    return Exercises(
      libraryWait: libraryWait,
      remoteService: remote,
      noteService: notes,
      remote: access,
      service: local,
      libraryService: library,
      catalogService: catalog,
      preferenceService: preferences,
      onError: onError,
      onRestTimer: (exercise, seconds) async => timers[exercise] = seconds,
    );
  }

  setUp(() {
    reset(local);
    reset(library);
    reset(catalog);
    reset(preferences);
    timers.clear();
    notes.values.clear();
    notes.sent.clear();
    notes.fails = false;
    access.account = true;

    when(preferences.getExercisePreferences()).thenAnswer((_) async => <ExercisePreference>[]);

    when(local.getExercises()).thenAnswer((_) async => (null, <Exercise>[]));
    when(local.storeExercises(any)).thenAnswer((_) async {});

    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    // an empty library under a fresh stamp, unless a test says otherwise
    when(library.getLibrary(cached: anyNamed('cached')))
        .thenAnswer((_) async => ((exercises: <Exercise>[], glossary: SearchGlossary.empty()), stamp));
    when(catalog.getCatalogStamp()).thenAnswer((_) async => null);
    when(catalog.getSearchGlossary()).thenAnswer((_) async => null);
    when(catalog.storeCatalog(any, stamp: anyNamed('stamp'), glossary: anyNamed('glossary'))).thenAnswer((_) async {});

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

  test('anonymous pin persists, restores, and clears without a remote call', () async {
    access.account = false;
    await sut.setNote('bench', '  Pause  ');
    expect(sut.noteFor('bench'), 'Pause');
    expect(notes.values, {'bench': 'Pause'});
    expect(notes.sent, isEmpty);
    final reopened = build()..userId = 'u1';
    await reopened.init();
    expect(reopened.noteFor('bench'), 'Pause');
    await reopened.setNote('bench', null);
    expect(notes.values, isEmpty);
  });

  test('failed signed-in pin leaves local default intact', () async {
    await sut.setNote('bench', 'Original');
    notes.fails = true;
    await expectLater(sut.setNote('bench', 'Changed'), throwsStateError);
    expect(sut.noteFor('bench'), 'Original');
    await expectLater(sut.setNote('bench', 'x' * 201), throwsArgumentError);
    sut.onSignOut();
    expect(sut.noteFor('bench'), isNull);
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
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[e2], glossary: SearchGlossary.empty()), stamp));

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.isInitialized, isTrue);
      expect(sut.lookup(e1.id), e1);
      expect(sut.lookup(e2.id), e2);
      expect(probe.notifications, 2); // 1 for local, 1 for the sync

      verify(local.getExercises(userId: anyNamed('userId'))).called(1);
      verify(catalog.getCatalogStamp()).called(1);
      verify(library.getLibrary(cached: null)).called(1);
      verify(catalog.storeCatalog([e2], stamp: stamp, glossary: anyNamed('glossary'))).called(1);
      verify(remote.getOwnExercises()).called(1);
      // the API's library list is no longer read — the CDN is the catalog
      verifyNever(remote.getExercises());
    });

    test('when local is empty, the library still loads, sets initialized and notifies once', () async {
      final e1 = ex('Squat');
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[e1], glossary: SearchGlossary.empty()), stamp));

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.isInitialized, isTrue);
      expect(sut.lookup(e1.id), e1);
      expect(probe.notifications, 1); // 1 for the sync (none for empty local)

      // a stamp over an empty catalog is not consulted, let alone trusted
      verifyNever(catalog.getCatalogStamp());
      verify(library.getLibrary(cached: null)).called(1);
      verify(catalog.storeCatalog([e1], stamp: stamp, glossary: anyNamed('glossary'))).called(1);
    });

    test('the catalog from the CDN and the customs from the API merge into one map by id', () async {
      final bench = ex('Bench Press');
      final curl = Exercise(name: 'My Curl', category: .dumbbell, target: .arms).copyWith(isMine: true);
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[curl]);

      await sut.init();

      expect(sut.lookup(bench.id), bench);
      expect(sut.lookup(curl.id), curl);
      expect(sut.hasOwn, isTrue);
      expect(sut.map((each) => each.id).toSet(), {bench.id, curl.id});
      // each half lands in the cache through its own door
      verify(catalog.storeCatalog([bench], stamp: stamp, glossary: anyNamed('glossary'))).called(1);
      verify(local.storeExercises([curl], userId: 'u1')).called(1);
    });

    // the server keeps no movement on a custom exercise (#343): its empty one
    // is silence, and the pattern the user gave it on this device stays
    test("a custom's pattern survives the server's copy, which has none", () async {
      Exercise curl(List<String> groups) => Exercise.fromJson({
        'id': 'id-curl',
        'name': 'My Curl',
        'category': 'Dumbbell',
        'target': 'Arms',
        'own': true,
        if (groups.isNotEmpty) 'movement': {'groups': groups},
      });
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer(
        (_) async => (
          null,
          [
            curl(['elbow_flexion']),
          ],
        ),
      );
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[curl([])]);

      await sut.init();

      expect(sut.lookup('id-curl')?.movement.groups, ['elbow_flexion']);
      final [stored] = verify(local.storeExercises(captureAny, userId: 'u1')).captured.single as List<Exercise>;
      expect(stored.movement.groups, ['elbow_flexion']);
    });

    // nor muscles (#176): the tagging the user picked on the atlas stays, so
    // the muscle map and the pattern lens keep counting the custom's sets
    test("a custom's muscles survive the server's copy, which has none", () async {
      Exercise curl({bool tagged = false}) => Exercise.fromJson({
        'id': 'id-curl',
        'name': 'My Curl',
        'category': 'Dumbbell',
        'target': 'Arms',
        'own': true,
        if (tagged)
          'muscles': {
            'primary': {
              'ids': ['biceps_brachii_caput_longum_l', 'biceps_brachii_caput_longum_r'],
            },
            'secondary': {
              'ids': ['brachialis_l', 'brachialis_r'],
            },
          },
      });
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [curl(tagged: true)]));
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[curl()]);

      await sut.init();

      expect(sut.lookup('id-curl')?.muscles.primary.ids, [
        'biceps_brachii_caput_longum_l',
        'biceps_brachii_caput_longum_r',
      ]);
      final [stored] = verify(local.storeExercises(captureAny, userId: 'u1')).captured.single as List<Exercise>;
      expect(stored.muscles.secondary?.ids, ['brachialis_l', 'brachialis_r']);
    });

    test("the server's own movement on a custom wins over the device's", () async {
      Exercise curl(String group) => Exercise.fromJson({
        'id': 'id-curl',
        'name': 'My Curl',
        'category': 'Dumbbell',
        'target': 'Arms',
        'own': true,
        'movement': {
          'groups': [group],
        },
      });
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [curl('elbow_flexion')]));
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[curl('forearm')]);

      await sut.init();

      expect(sut.lookup('id-curl')?.movement.groups, ['forearm']);
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

    // The catalog comes from the CDN, which knows nothing about accounts: a
    // preference set on a library exercise rides no list the app reads, and
    // without this read it would not survive a reinstall or reach a second
    // device.
    test('a preference on a library exercise is mirrored locally', () async {
      final bench = ex('Bench Press');
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
      when(preferences.getExercisePreferences()).thenAnswer(
        (_) async => [ExercisePreference(exerciseId: bench.id, unitSystem: .imperial)],
      );

      await sut.init();

      expect(sut.unitFor(bench.id), MeasurementUnit.imperial);
      verify(local.setExerciseUnit(exerciseName: bench.id, userId: 'u1', unit: MeasurementUnit.imperial)).called(1);
    });

    test('note-only preferences restore and cancelled pins clear the cache', () async {
      final bench = ex('Bench Press');
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
      when(preferences.getExercisePreferences()).thenAnswer(
        (_) async => [ExercisePreference(exerciseId: bench.id, note: 'Pause')],
      );
      await sut.init();
      expect(sut.noteFor(bench.id), 'Pause');
      expect(notes.values[bench.id], 'Pause');
      when(preferences.getExercisePreferences()).thenAnswer((_) async => []);
      await sut.init();
      expect(sut.noteFor(bench.id), isNull);
      expect(notes.values, isEmpty);
    });

    test("the account's own exercises failing to read costs the preferences nothing (#681)", () async {
      final bench = ex('Bench Press');
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
      when(remote.getOwnExercises()).thenThrow(const ServerFailed());
      when(preferences.getExercisePreferences()).thenAnswer(
        (_) async => [ExercisePreference(exerciseId: bench.id, unitSystem: .imperial)],
      );

      await sut.init();

      expect(sut.unitFor(bench.id), MeasurementUnit.imperial);
    });

    test('a preference read that fails keeps every note, rather than reading as none (#681)', () async {
      final bench = ex('Bench Press');
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
      when(preferences.getExercisePreferences()).thenAnswer(
        (_) async => [ExercisePreference(exerciseId: bench.id, note: 'Pause')],
      );
      await sut.init();

      // a 5xx, a throttle, a 2xx it could not read: heart_api throws them all
      for (final failure in [
        const ServerFailed(),
        refusedAs({'code': 'rate_limited'}, status: 429),
        const FormatException('an answer this build cannot read'),
      ]) {
        when(preferences.getExercisePreferences()).thenThrow(failure);
        await sut.init();
        expect(sut.noteFor(bench.id), 'Pause');
        expect(notes.values[bench.id], 'Pause');
      }
    });

    test('a catalog gap preserves a cached pin until its exercise can be reconciled', () async {
      final bench = ex('Bench Press');
      notes.values[bench.id] = 'Pause';
      await sut.init();
      expect(sut.noteFor(bench.id), 'Pause');
      expect(notes.values[bench.id], 'Pause');

      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
      await sut.init();
      expect(sut.noteFor(bench.id), isNull);
      expect(notes.values, isEmpty);
    });

    test('a rest timer goes to Timers rather than a store of its own', () async {
      final bench = ex('Bench Press');
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
      when(preferences.getExercisePreferences()).thenAnswer(
        (_) async => [ExercisePreference(exerciseId: bench.id, restTimer: 90)],
      );

      await sut.init();

      expect(timers, {bench.id: 90});
      expect(sut.unitFor(bench.id), isNull);
    });

    // the account is the source of truth for a signed-in device; what an
    // anonymous session set offline is the upsync's problem, not this read's
    test('the server overrides what the local mirror holds', () async {
      final bench = ex('Bench Press');
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
      when(local.getExerciseUnits('u1')).thenAnswer((_) async => {bench.id: MeasurementUnit.metric});
      when(preferences.getExercisePreferences()).thenAnswer(
        (_) async => [ExercisePreference(exerciseId: bench.id, unitSystem: .imperial)],
      );

      await sut.init();

      expect(sut.unitFor(bench.id), MeasurementUnit.imperial);
    });

    // both local stores key their rows by a foreign key onto `exercises.id`
    test('a preference on an exercise the device does not hold is dropped', () async {
      when(preferences.getExercisePreferences()).thenAnswer(
        (_) async => [ExercisePreference(exerciseId: 'unpublished', unitSystem: .metric, restTimer: 60)],
      );

      await sut.init();

      expect(sut.unitFor('unpublished'), isNull);
      expect(timers, isEmpty);
      verifyNever(
        local.setExerciseUnit(
          exerciseName: anyNamed('exerciseName'),
          userId: anyNamed('userId'),
          unit: anyNamed('unit'),
        ),
      );
    });

    // the catalog is what the rest of start-up is chained behind; a preference
    // is not, so it must not be able to stop it
    test('a failed preference read is reported, and the catalog still stands', () async {
      Object? err;
      sut = build(onError: (e, {stacktrace}) => err = e)..userId = 'u1';
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[ex('Squat')], glossary: SearchGlossary.empty()), stamp));
      when(preferences.getExercisePreferences()).thenThrow(Exception('preferences down'));

      expect(await sut.init(), isTrue);

      expect(sut.isInitialized, isTrue);
      expect(sut.map((each) => each.name), ['Squat']);
      expect(err, isNotNull);
    });

    test('with no user keyed in there is nobody to hold preferences, and none are asked for', () async {
      sut = build()..userId = null;

      await sut.init();

      verifyNever(preferences.getExercisePreferences());
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
    });

    test("a CDN failure does not cost the user's own exercises their sync", () async {
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(library.getLibrary(cached: anyNamed('cached'))).thenThrow(Exception('cdn down'));
      when(remote.getOwnExercises()).thenAnswer((_) async => [ex('My Carry').copyWith(isMine: true)]);

      // their own exercises alone are not a catalog the rest of start-up can
      // write against, so init still answers false
      expect(await sut.init(), isFalse);

      verify(remote.getOwnExercises()).called(1);
      expect(sut.map((each) => each.name), contains('My Carry'));
    });

    test('a local read that fails does not keep the CDN from refreshing the catalog', () async {
      when(local.getExercises(userId: anyNamed('userId'))).thenThrow(StateError('unreadable'));
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer(
        (_) async => ((exercises: [ex('Squat')], glossary: SearchGlossary.empty()), stamp),
      );

      expect(await sut.init(), isTrue);

      expect(sut.map((each) => each.name), contains('Squat'));
    });

    test('a current library is not re-stored; a moved stamp is', () async {
      const moved = (version: 'run-2', locale: 'en', etag: null);
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (DateTime(2024), [ex('Squat')]));
      when(catalog.getCatalogStamp()).thenAnswer((_) async => stamp);
      when(library.getLibrary(cached: stamp)).thenAnswer((_) async => (null, stamp));

      await sut.init(locale: 'en');

      verifyNever(catalog.storeCatalog(any, stamp: anyNamed('stamp'), glossary: anyNamed('glossary')));

      when(library.getLibrary(cached: stamp)).thenAnswer((_) async => (null, moved));
      await sut.onLocaleChanged('en-CA');

      verify(catalog.storeCatalog(<Exercise>[], stamp: moved, glossary: anyNamed('glossary'))).called(1);
    });

    test('a cache holding only customs does not vouch for a library', () async {
      final mine = ex('My Thing').copyWith(isMine: true);
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (DateTime(2024), [mine]));
      when(catalog.getCatalogStamp()).thenAnswer((_) async => stamp);

      await sut.init();

      verifyNever(catalog.getCatalogStamp());
      verify(library.getLibrary(cached: null)).called(1);
    });

    // #612: a stamp passes every comparison the manifest makes, so rows that
    // disagree with it would never be replaced
    test('a Russian stamp over English rows is not trusted, and is reported', () async {
      const inRussian = (version: 'run-1', locale: 'ru', etag: '"abc"');
      final errors = <Object?>[];
      sut = build(onError: (e, {stacktrace}) => errors.add(e))..userId = 'u1';
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (DateTime(2024), [ex('Squat')]));
      when(catalog.getCatalogStamp()).thenAnswer((_) async => inRussian);

      await sut.init(locale: 'ru-RU');

      verify(library.getLibrary(cached: null)).called(1);
      expect(errors, [
        isA<CatalogLanguageMismatch>()
            .having((e) => e.stamped, 'stamped', 'ru')
            .having((e) => e.device, 'device', 'ru-RU'),
      ]);
    });

    test('a Russian stamp over Russian rows is trusted', () async {
      const inRussian = (version: 'run-1', locale: 'ru', etag: '"abc"');
      final errors = <Object?>[];
      sut = build(onError: (e, {stacktrace}) => errors.add(e))..userId = 'u1';
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer(
        (_) async => (DateTime(2024), [ex('Squat'), ex('Приседания (штанга)')]),
      );
      when(catalog.getCatalogStamp()).thenAnswer((_) async => inRussian);
      when(library.getLibrary(cached: inRussian)).thenAnswer((_) async => (null, inRussian));

      await sut.init(locale: 'ru-RU');

      verify(library.getLibrary(cached: inRussian)).called(1);
      expect(errors, isEmpty);
    });

    test('routes errors to onError and does not throw', () async {
      Object? err;
      sut = build(onError: (e, {stacktrace}) => err = e);
      when(local.getExercises()).thenThrow(Exception('boom'));

      await sut.init();

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
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[en], glossary: SearchGlossary.empty()), stamp));
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
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[ru], glossary: SearchGlossary.empty()), inRussian));

      await sut.onLocaleChanged('ru');

      expect(sut.lookup(en.id)?.name, 'Жим лёжа');
      expect(sut.where((each) => each.id == en.id), hasLength(1));
      verify(catalog.storeCatalog([ru], stamp: inRussian, glossary: anyNamed('glossary'))).called(1);
      // customs are not localized, so the API has no part in this
      verifyNever(remote.getOwnExercises());
    });

    test('the same tag again is a no-op', () async {
      final en = ex('Bench Press');
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[en], glossary: SearchGlossary.empty()), stamp));
      await sut.init(locale: 'en');

      // were a fetch to happen, this copy would show up
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer(
        (_) async => (
          (
            exercises: <Exercise>[
              Exercise.fromJson({
                'id': en.id,
                'name': 'Жим лёжа',
                'category': 'Weighted Body Weight',
                'target': 'Chest',
              }),
            ],
            glossary: SearchGlossary.empty(),
          ),
          stamp,
        ),
      );

      await sut.onLocaleChanged('en');

      expect(sut.lookup(en.id)?.name, 'Bench Press');
    });

    test('a fetch that fails keeps the old tag, so the same change tries again', () async {
      await sut.init(locale: 'en');
      when(library.getLibrary(cached: anyNamed('cached'))).thenThrow(Exception('offline'));

      await sut.onLocaleChanged('ru');

      when(library.getLibrary(cached: anyNamed('cached')))
          .thenAnswer((_) async => ((exercises: <Exercise>[], glossary: SearchGlossary.empty()), stamp));
      clearInteractions(library);
      await sut.onLocaleChanged('ru');

      verify(library.getLibrary(cached: anyNamed('cached'))).called(1);
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
      await sut.init();

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
      await sut.init();

      sut.addFilter(Category.weightedBodyWeight);
      sut.addFilter(Target.chest);

      final filtered = sut.search('press', filters: true).toList();
      expect(filtered, [a]);

      // without filters flag, both would match by name query (if query matches)
      final all = sut.search('press', filters: false).toList();
      expect(all, [a]);
    });
  });

  test('showing only one filter is asked for; a filter set in the picker, or none left, is not (#711)', () {
    var notified = 0;
    sut.addListener(() => notified++);
    sut.addFilter(Category.barbell);
    expect(sut.filtersAskedFor, isFalse);

    sut.showOnly(const PatternFilter('horizontal_press'));
    expect(sut.filters, [const PatternFilter('horizontal_press')]);
    expect(sut.filtersAskedFor, isTrue);
    expect(notified, 2);

    sut.addFilter(Target.chest);
    expect(sut.filtersAskedFor, isFalse);

    sut.showOnly(Target.legs);
    sut.removeFilter(Target.legs);
    expect(sut.filtersAskedFor, isFalse);

    sut.showOnly(Target.legs);
    sut.clearFilters();
    expect(sut.filtersAskedFor, isFalse);
  });

  group('search() ranking (#135)', () {
    Exercise lift(String name, {String? key, List<String>? aliases, String category = 'Barbell'}) {
      return Exercise.fromJson({
        'id': 'id-${name.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '-')}',
        'key': ?key,
        'name': name,
        'category': category,
        'target': 'Chest',
        'aliases': ?aliases,
      });
    }

    final barbell = lift('Bench Press (Barbell)', key: 'bench-press-barbell');
    final dumbbell = lift('Bench Press (Dumbbell)', key: 'bench-press-dumbbell', category: 'Dumbbell');
    final incline = lift('Incline Bench Press (Dumbbell)', key: 'incline-bench-press-dumbbell', category: 'Dumbbell');
    final overhead = lift('Overhead Press (Barbell)', key: 'overhead-press-barbell', aliases: ['ohp']);

    Future<void> serve(List<Exercise> exercises, {Map<String, dynamic> glossary = const {}}) async {
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer(
        (_) async => ((exercises: exercises, glossary: SearchGlossary.fromJson(glossary)), stamp),
      );
      await sut.init();
    }

    test('a recent exercise leads its own tier and never jumps a better match', () async {
      await serve([barbell, dumbbell, incline]);
      final done = {incline.id: DateTime(2026, 10, 3), dumbbell.id: DateTime(2026, 9, 1)};

      // both Bench Press names start with the query and lead; the dumbbell
      // was done, so it leads the two. The incline matches only by word and
      // stays behind them however recent it is.
      expect(sut.search('bench', lastDone: done.get), [dumbbell, barbell, incline]);
      // without recency, the library's own order
      expect(sut.search('bench'), [barbell, dumbbell, incline]);
    });

    test('an empty query ranks by recency alone, never-done in library order after', () async {
      await serve([barbell, dumbbell, incline]);
      final done = {incline.id: DateTime(2026, 10, 3)};

      expect(sut.search('', lastDone: done.get), [incline, barbell, dumbbell]);
    });

    test('aliases and the glossary come with the library, typos match last', () async {
      await serve(
        [barbell, incline, overhead],
        glossary: {
          'db': {
            'words': ['dumbbell'],
          },
        },
      );

      expect(sut.search('ohp'), [overhead]);
      expect(sut.search('db incline'), [incline]);
      expect(sut.search('benhc'), [barbell, incline]);
      verify(
        catalog.storeCatalog(
          any,
          stamp: stamp,
          glossary: argThat(isNotNull, named: 'glossary'),
        ),
      ).called(1);
    });

    test('offline, the glossary stored with the catalog still applies', () async {
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[incline]));
      when(catalog.getSearchGlossary()).thenAnswer(
        (_) async => SearchGlossary.fromJson({
          'db': {
            'words': ['dumbbell'],
          },
        }),
      );
      when(library.getLibrary(cached: anyNamed('cached'))).thenThrow(const SocketLikeFailure());

      await sut.init();

      expect(sut.search('db'), [incline]);
    });

    test('recent() is the newest few, done ones only, under the same filters', () async {
      await serve([barbell, dumbbell, incline, overhead]);
      final done = {
        barbell.id: DateTime(2026, 9, 1),
        dumbbell.id: DateTime(2026, 9, 20),
        overhead.id: DateTime(2026, 10, 1),
      };

      expect(sut.recent(done.get), [overhead, dumbbell, barbell]);
      expect(sut.recent(done.get, limit: 2), [overhead, dumbbell]);

      sut.addFilter(Category.dumbbell);
      expect(sut.recent(done.get, filters: true), [dumbbell]);
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
        await sut.init();

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
      await sut.init();

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
      await sut.init();

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

      await sut.init();

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
      await sut.init();

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

  group('editExercise (#616)', () {
    late _Renames renames;
    final own = Exercise.fromJson({
      'id': 'own-1',
      'name': 'Landmine Press',
      'category': 'Barbell',
      'target': 'Shoulders',
      'own': 1,
    });

    setUp(() async {
      renames = _Renames();
      sut = Exercises(
        remoteService: remote,
        remote: access,
        service: local,
        libraryService: library,
        catalogService: catalog,
        preferenceService: preferences,
        renameService: renames,
      )..userId = 'u1';
      when(remote.editExercise(any)).thenAnswer((i) async => i.positionalArguments.first as Exercise);
      await sut.makeExercise(own);
      clearInteractions(remote);
    });

    test('a new name goes through the rename', () async {
      await sut.editExercise(own.renamed('Half-kneeling Press'));

      expect(renames.sent.single.name, 'Half-kneeling Press');
      verifyNever(remote.editExercise(any));
      expect(sut.lookup(own.id)?.name, 'Half-kneeling Press');
    });

    test('an edit that keeps the name never sends one', () async {
      await sut.editExercise(own.copyWith(target: .chest));

      expect(renames.sent, isEmpty);
      verify(remote.editExercise(any)).called(1);
    });

    test('archiving acts on the current copy, not the one it was handed', () async {
      await sut.editExercise(own.renamed('Half-kneeling Press'));

      await sut.archive(own);

      final archived = verify(remote.editExercise(captureAny)).captured.single as Exercise;
      expect(archived.name, 'Half-kneeling Press');
      expect(archived.isArchived, isTrue);
    });
  });

  group('an edit with the server out of reach (#616)', () {
    late _Renames renames;
    late _Unsent unsent;
    final own = Exercise.fromJson({
      'id': 'own-1',
      'name': 'Landmine Press',
      'category': 'Barbell',
      'target': 'Shoulders',
      'own': 1,
    });
    final offline = Exception('Connection failed');

    setUp(() async {
      renames = _Renames();
      unsent = _Unsent();
      sut = Exercises(
        remoteService: remote,
        remote: access,
        service: local,
        libraryService: library,
        catalogService: catalog,
        preferenceService: preferences,
        renameService: renames,
        unsentService: unsent,
      )..userId = 'u1';
      when(remote.editExercise(any)).thenAnswer((i) async => i.positionalArguments.first as Exercise);
      when(remote.getOwnExercises()).thenAnswer((_) async => [own]);
      await sut.makeExercise(own);
      sut.isInitialized = true;
      clearInteractions(remote);
      clearInteractions(local);
    });

    tearDown(() => access.account = true);

    test('a rename sticks, is marked, and reaches the server on the next sync', () async {
      renames.failure = offline;
      await sut.editExercise(own.renamed('Half-kneeling Press'));

      expect(sut.lookup(own.id)?.name, 'Half-kneeling Press');
      expect(unsent.marked['u1'], {own.id: UnsentExerciseEdit.renamed});
      expect(sut.hasUnsentEdits, isTrue);

      // still out of reach: the device's copy stands, and nothing is reported
      await sut.sendUnsentEdits();
      expect(sut.lookup(own.id)?.name, 'Half-kneeling Press');
      expect(unsent.marked['u1'], {own.id: UnsentExerciseEdit.renamed});

      renames.failure = null;
      await sut.sendUnsentEdits();

      expect(renames.sent.single.name, 'Half-kneeling Press');
      expect(sut.lookup(own.id)?.name, 'Half-kneeling Press');
      expect(unsent.marked['u1'], isEmpty);
      expect(sut.hasUnsentEdits, isFalse);
      final stored = verify(local.storeExercises(captureAny, userId: 'u1')).captured.last as Iterable<Exercise>;
      expect(stored.single.name, 'Half-kneeling Press');
    });

    test('a relaunch reads the mark, and the sync sends the edit before it takes the list', () async {
      renames.failure = offline;
      await sut.editExercise(own.renamed('Half-kneeling Press'));
      renames.failure = null;

      final relaunched = Exercises(
        remoteService: remote,
        remote: access,
        service: local,
        libraryService: library,
        catalogService: catalog,
        preferenceService: preferences,
        renameService: renames,
        unsentService: unsent,
      )..userId = 'u1';
      when(local.getExercises(userId: 'u1')).thenAnswer(
        (_) async => (null, [own.renamed('Half-kneeling Press')]),
      );
      when(local.getExerciseUnits('u1')).thenAnswer((_) async => {});
      await relaunched.init();

      expect(renames.sent.single.name, 'Half-kneeling Press');
      expect(relaunched.lookup(own.id)?.name, 'Half-kneeling Press');
      expect(unsent.marked['u1'], isEmpty);
    });

    test('a refusal is thrown, and nothing changes', () async {
      renames.failure = const _NameTaken();

      await expectLater(sut.editExercise(own.renamed('Sled Push')), throwsA(isA<_NameTaken>()));

      expect(sut.lookup(own.id)?.name, 'Landmine Press');
      expect(unsent.marked['u1'] ?? const {}, isEmpty);
    });

    test('a rename refused later costs the name only: the rest of the edit goes up', () async {
      renames.failure = offline;
      await sut.editExercise(own.renamed('Sled Push').copyWith(target: .chest));
      renames.failure = const _NameTaken();

      final renamed = await sut.sendUnsentEdits();

      expect(renamed, {own.id}, reason: 'the holders of a copy read it again');

      final sent = verify(remote.editExercise(captureAny)).captured.single as Exercise;
      expect(sent.name, 'Landmine Press');
      expect(sent.target, Target.chest);
      expect(sut.lookup(own.id)?.name, 'Landmine Press');
      expect(sut.lookup(own.id)?.target, Target.chest);
      expect(unsent.marked['u1'], isEmpty);
    });

    test('an edit that kept the name never undoes a rename made elsewhere', () async {
      when(remote.editExercise(any)).thenThrow(offline);
      await sut.editExercise(own.copyWith(target: .chest));
      expect(unsent.marked['u1'], {own.id: UnsentExerciseEdit.named});
      when(remote.editExercise(any)).thenAnswer((i) async => i.positionalArguments.first as Exercise);
      when(remote.getOwnExercises()).thenAnswer((_) async => [own.renamed('Half-kneeling Press')]);
      clearInteractions(remote);

      final renamed = await sut.sendUnsentEdits();

      expect(renames.sent, isEmpty);
      final sent = verify(remote.editExercise(captureAny)).captured.single as Exercise;
      expect(sent.target, Target.chest);
      expect(sut.lookup(own.id)?.name, 'Half-kneeling Press');
      expect(sut.lookup(own.id)?.target, Target.chest);
      expect(renamed, {own.id});
      expect(unsent.marked['u1'], isEmpty);
    });

    test('any other refusal of an unsent rename drops the edit for the server\'s copy, and is reported', () async {
      final reported = <Object>[];
      sut = Exercises(
        onError: (error, {stacktrace}) => reported.add(error as Object),
        remoteService: remote,
        remote: access,
        service: local,
        libraryService: library,
        catalogService: catalog,
        preferenceService: preferences,
        renameService: renames,
        unsentService: unsent,
      )..userId = 'u1';
      await sut.makeExercise(own);
      sut.isInitialized = true;
      renames.failure = offline;
      await sut.editExercise(own.renamed('Sled Push'));
      renames.failure = const FormatException('unreadable');
      clearInteractions(remote);

      await sut.sendUnsentEdits();

      verifyNever(remote.editExercise(any));
      expect(reported.single, isFormatException);
      expect(sut.lookup(own.id)?.name, 'Landmine Press');
      expect(unsent.marked['u1'], isEmpty);
    });

    test('a mark on an exercise the account no longer lists is dropped', () async {
      renames.failure = offline;
      await sut.editExercise(own.renamed('Half-kneeling Press'));
      when(remote.getOwnExercises()).thenAnswer((_) async => []);

      await sut.sendUnsentEdits();

      expect(unsent.marked['u1'], isEmpty);
      expect(sut.hasUnsentEdits, isFalse);
    });

    test('an edit saved while the list is on its way is not undone by it', () async {
      final other = Exercise.fromJson({
        'id': 'own-2',
        'name': 'Sled Push',
        'category': 'Machine',
        'target': 'Legs',
        'own': 1,
      });
      await sut.makeExercise(other);
      renames.failure = offline;
      await sut.editExercise(own.renamed('Half-kneeling Press'));
      renames.failure = null;
      final list = Completer<Iterable<Exercise>>();
      when(remote.getOwnExercises()).thenAnswer((_) => list.future);

      final sending = sut.sendUnsentEdits();
      await sut.editExercise(other.renamed('Prowler Push'));
      list.complete([own, other]);
      await sending;

      expect(sut.lookup(other.id)?.name, 'Prowler Push');
      expect(sut.lookup(own.id)?.name, 'Half-kneeling Press');
    });

    test('a unit the server lists is banked; the kept copy\'s old one is not', () async {
      final imperial = Exercise.fromJson({...own.toMap(), 'unitSystem': 'imperial'});
      renames.failure = offline;
      await sut.editExercise(imperial.renamed('Half-kneeling Press'));
      renames.failure = null;
      clearInteractions(local);

      await sut.sendUnsentEdits();

      verifyNever(local.setExerciseUnit(exerciseName: own.id, userId: 'u1', unit: anyNamed('unit')));
    });

    test('an edit made while an older one is being sent keeps its mark (#616)', () async {
      renames.failure = offline;
      await sut.editExercise(own.renamed('First Name'));
      final sending = Completer<void>();
      renames.gate = sending.future;
      renames.failure = null;

      final resend = sut.sendUnsentEdits();
      await pumpEventQueue();
      // the second edit, saved while the first is on its way, and out of reach
      renames
        ..gate = null
        ..failure = offline;
      await sut.editExercise(own.renamed('Second Name'));
      renames.failure = null;
      sending.complete();
      await resend;

      expect(sut.lookup(own.id)?.name, 'Second Name');
      expect(unsent.marked['u1'], {own.id: UnsentExerciseEdit.renamed});

      await sut.sendUnsentEdits();
      expect(renames.sent.last.name, 'Second Name');
      expect(unsent.marked['u1'], isEmpty);
    });

    test('an archive made out of reach is kept, marked and sent later, not undone by the list (#616)', () async {
      when(remote.editExercise(any)).thenThrow(offline);

      await sut.archive(own);

      expect(sut.lookup(own.id)?.isArchived, isTrue);
      expect(unsent.marked['u1'], {own.id: UnsentExerciseEdit.named});
      when(remote.editExercise(any)).thenAnswer((i) async => i.positionalArguments.first as Exercise);
      clearInteractions(remote);

      await sut.sendUnsentEdits();

      final sent = verify(remote.editExercise(captureAny)).captured.single as Exercise;
      expect(sent.isArchived, isTrue);
      expect(sut.lookup(own.id)?.isArchived, isTrue);
      expect(unsent.marked['u1'], isEmpty);
    });

    test('a resend tells who holds a copy, and reports what fails on the device itself (#616)', () async {
      final reported = <Object>[];
      final told = <Set<String>>[];
      sut =
          Exercises(
              onError: (error, {stacktrace}) => reported.add(error as Object),
              remoteService: remote,
              remote: access,
              service: local,
              libraryService: library,
              catalogService: catalog,
              preferenceService: preferences,
              renameService: renames,
              unsentService: unsent,
            )
            ..userId = 'u1'
            ..onOwnRenamed = told.add;
      await sut.makeExercise(own);
      sut.isInitialized = true;
      renames.failure = offline;
      await sut.editExercise(own.renamed('Sled Push'));

      // out of reach still: nothing told, nothing reported
      when(remote.getOwnExercises()).thenThrow(offline);
      await sut.sendUnsentEdits();
      expect(reported, isEmpty);
      expect(told, isEmpty);

      // refused: back under the server's name, and the holders are told
      when(remote.getOwnExercises()).thenAnswer((_) async => [own]);
      renames.failure = const _NameTaken();
      await sut.sendUnsentEdits();
      expect(told.single, {own.id});

      // the mirror fails: the device's own failure, reported
      renames.failure = offline;
      await sut.editExercise(own.renamed('Prowler Push'));
      renames.failure = null;
      when(local.storeExercises(any, userId: anyNamed('userId'))).thenThrow(StateError('disk'));
      addTearDown(() => when(local.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {}));
      await sut.sendUnsentEdits();
      expect(reported.single, isStateError);
    });

    test('marks that cannot be read cost the session neither its units nor its notes (#616)', () async {
      final broken = _Unsent()..fails = true;
      final relaunched = Exercises(
        onError: (_, {stacktrace}) {},
        remoteService: remote,
        remote: access,
        service: local,
        libraryService: library,
        catalogService: catalog,
        preferenceService: preferences,
        renameService: renames,
        unsentService: broken,
      )..userId = 'u1';
      when(local.getExercises(userId: 'u1')).thenAnswer((_) async => (null, [own]));
      when(local.getExerciseUnits('u1')).thenAnswer((_) async => {own.id: MeasurementUnit.imperial});
      addTearDown(() => when(local.getExerciseUnits('u1')).thenAnswer((_) async => {}));

      await relaunched.init();

      expect(relaunched.unitFor(own.id), MeasurementUnit.imperial);
    });

    test('archiving an unsent rename sends the name with it', () async {
      renames.failure = offline;
      await sut.editExercise(own.renamed('Half-kneeling Press'));
      renames.failure = null;

      await sut.archive(own);

      expect(renames.sent.single.name, 'Half-kneeling Press');
      expect(renames.sent.single.isArchived, isTrue);
      expect(unsent.marked['u1'], isEmpty);
    });

    test('without an account the edit is the device\'s alone, and is not marked', () async {
      access.account = false;

      await sut.editExercise(own.renamed('Half-kneeling Press'));

      expect(sut.lookup(own.id)?.name, 'Half-kneeling Press');
      expect(renames.sent, isEmpty);
      expect(unsent.marked['u1'] ?? const {}, isEmpty);
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
    test('iterator, index operator, and sign-out says so', () async {
      when(
        local.getExercises(userId: anyNamed('userId')),
      ).thenAnswer(
        (_) async => (null, <Exercise>[ex('A'), ex('B')]),
      );
      await sut.init();

      // iterator and []
      expect(sut.map((e) => e.name).toList(), ['A', 'B']);
      expect(sut[0].name, 'A');

      final probe = ListenerProbe()..attach(sut);
      sut.onSignOut();
      expect(probe.notifications, 1);
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
      await sut.init();
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
      await sut.init();
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
      await sut.init();
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

  group('moveHistory() (#338)', () {
    late _MoveFake moves;

    Exercises withMoves() {
      return Exercises(
        remoteService: remote,
        noteService: notes,
        moveService: moves,
        remote: access,
        service: local,
        libraryService: library,
        catalogService: catalog,
        preferenceService: preferences,
      )..userId = 'u1';
    }

    setUp(() => moves = _MoveFake());

    test('is offered only with a move service and an account', () {
      expect(sut.canMoveHistory, isFalse);
      expect(withMoves().canMoveHistory, isTrue);
      access.account = false;
      expect(withMoves().canMoveHistory, isFalse);
    });

    test('a preview writes nowhere, on the server or in the mirror', () async {
      final custom = Exercise(name: 'My Bench', category: .barbell, target: .chest).copyWith(isMine: true);
      final bench = ex('Bench Press');
      final report = await withMoves().previewMove(custom, bench);

      expect(report.dryRun, isTrue);
      expect(moves.calls, [(custom.id, bench.id, true)]);
      expect(moves.mirrored, isEmpty);
    });

    test('a move mirrors the server, drops a deleted custom and reads units and notes again', () async {
      final custom = Exercise(name: 'My Bench', category: .barbell, target: .chest).copyWith(isMine: true);
      final bench = ex('Bench Press');
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[custom, bench]));
      when(local.getExerciseUnits('u1')).thenAnswer((_) async => {bench.id: MeasurementUnit.imperial});

      final sut = withMoves();
      await sut.init();
      expect(sut.lookup(custom.id), isNotNull);
      // the source's pin, re-keyed by the mirror; init's own sync has run
      notes.values[bench.id] = 'Pause';

      final probe = ListenerProbe()..attach(sut);
      final report = await sut.moveHistory(custom, bench);

      expect(report.sourceDeleted, isTrue);
      expect(moves.calls, [(custom.id, bench.id, false)]);
      expect(moves.mirrored, [(report, 'u1')]);
      expect(sut.lookup(custom.id), isNull);
      expect(sut.unitFor(bench.id), MeasurementUnit.imperial);
      expect(sut.noteFor(bench.id), 'Pause');
      expect(probe.notifications, 1);
    });

    test('a mirror that fails to follow is reported; the move still stands', () async {
      final errors = <Object>[];
      moves.mirrorFails = true;
      final sut = Exercises(
        remoteService: remote,
        moveService: moves,
        remote: access,
        service: local,
        libraryService: library,
        catalogService: catalog,
        preferenceService: preferences,
        onError: (e, {stacktrace}) => errors.add(e),
      )..userId = 'u1';
      when(local.getExerciseUnits('u1')).thenAnswer((_) async => {});

      final report = await sut.moveHistory(ex('Squat'), ex('Bench Press'));

      expect(report.dryRun, isFalse);
      expect(errors, [isA<StateError>()]);
    });

    test('a refused move changes nothing here', () async {
      moves.fails = true;
      final bench = ex('Bench Press');
      final sut = withMoves();
      await expectLater(sut.moveHistory(ex('Squat'), bench), throwsStateError);
      expect(moves.mirrored, isEmpty);
    });
  });

  group('a library that does not come (#723)', () {
    const wait = Duration(milliseconds: 50);
    final curl = Exercise.fromJson({
      'id': 'id-curl',
      'name': 'My Curl',
      'category': 'Dumbbell',
      'target': 'Arms',
      'own': true,
    });
    final bench = ex('Bench Press');
    final arrived = ((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp);

    /// The next download, answered when the test says.
    Completer<(CatalogLibrary?, CatalogStamp)> held() {
      final download = Completer<(CatalogLibrary?, CatalogStamp)>();
      when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) => download.future);
      return download;
    }

    void fails() => when(library.getLibrary(cached: anyNamed('cached'))).thenThrow(const ServerFailed());

    void answers() => when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) async => arrived);

    test('is waited for no longer than the wait, reported, and the own exercises are read all the same', () async {
      held();
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[curl]);
      final errors = <Object?>[];
      final exercises = build(libraryWait: wait, onError: (e, {stacktrace}) => errors.add(e))..userId = 'u1';

      final populated = await exercises.init();

      expect(populated, isFalse, reason: 'nothing the chained start-up can write against');
      expect(exercises.isInitialized, isFalse);
      expect(exercises.libraryUnavailable, isTrue);
      expect(exercises.map((each) => each.id), [curl.id]);
      expect(errors.single, isA<LibraryStalled>());
    });

    test('a download that lands after the wait is taken, with the own leg read again over it', () async {
      final download = held();
      final exercises = build(libraryWait: wait)..userId = 'u1';
      await exercises.init();
      var ran = 0;
      exercises.whenInitialized('u1', () => ran++);
      clearInteractions(remote);
      clearInteractions(preferences);

      download.complete(arrived);
      await pumpEventQueue();

      expect(exercises.isInitialized, isTrue);
      expect(exercises.libraryUnavailable, isFalse);
      expect(exercises.lookup(bench.id), isNotNull);
      expect(ran, 1);
      verify(remote.getOwnExercises()).called(1);
      verify(preferences.getExercisePreferences()).called(1);
    });

    test('one that fails outright reads the same, and is not a stall', () async {
      fails();
      final errors = <Object?>[];
      final exercises = build(libraryWait: wait, onError: (e, {stacktrace}) => errors.add(e))..userId = 'u1';

      await exercises.init();

      expect(exercises.libraryUnavailable, isTrue);
      expect(errors.whereType<LibraryStalled>(), isEmpty);
    });

    test('a retry after a failure downloads afresh, reads the own leg, and puts the catalog in', () async {
      fails();
      final exercises = build(libraryWait: wait)..userId = 'u1';
      await exercises.init();
      answers();
      clearInteractions(remote);
      var told = 0;
      exercises.addListener(() => told++);

      final retry = exercises.retryLibrary();
      expect(exercises.retryingLibrary, isTrue);
      expect(identical(exercises.retryLibrary(), retry), isTrue, reason: 'one retry at a time');

      expect(await retry, isTrue);
      expect(exercises.isInitialized, isTrue);
      expect(exercises.libraryUnavailable, isFalse);
      expect(exercises.retryingLibrary, isFalse);
      expect(exercises.lookup(bench.id), isNotNull);
      expect(told, greaterThanOrEqualTo(2));
      verify(remote.getOwnExercises()).called(1);
    });

    test('a retry joins the download under way rather than start another', () async {
      final download = held();
      final exercises = build(libraryWait: const Duration(seconds: 5))..userId = 'u1';
      final init = exercises.init();
      await pumpEventQueue();
      final retry = exercises.retryLibrary();

      download.complete(arrived);
      expect(await init, isTrue);
      expect(await retry, isTrue);
      verify(library.getLibrary(cached: anyNamed('cached'))).called(1);
    });

    test('a retry that waits out the download lets go of it, and the next starts afresh', () async {
      final first = held();
      final exercises = build(libraryWait: wait)..userId = 'u1';
      await exercises.init();

      expect(await exercises.retryLibrary(), isFalse, reason: 'joined the hung one, and waited it out');
      expect(exercises.libraryUnavailable, isTrue);
      expect(exercises.retryingLibrary, isFalse);
      verify(library.getLibrary(cached: anyNamed('cached'))).called(1);

      answers();
      expect(await exercises.retryLibrary(), isTrue);
      verify(library.getLibrary(cached: anyNamed('cached'))).called(1);
      // the first landing late changes nothing more
      first.complete(arrived);
      await pumpEventQueue();
      expect(exercises.isInitialized, isTrue);
    });

    test('a retry the session ended under changes nothing for the next one', () async {
      fails();
      final exercises = build(libraryWait: wait)..userId = 'u1';
      await exercises.init();
      final download = held();

      final retry = exercises.retryLibrary();
      exercises
        ..onSignOut()
        ..userId = 'u2';
      download.complete(arrived);

      expect(await retry, isFalse);
      expect(exercises.isInitialized, isFalse);
      expect(exercises.lookup(bench.id), isNull, reason: "the last session's download is not the next one's");
      expect(exercises.libraryUnavailable, isFalse, reason: "the next session's init hasn't run");
      expect(exercises.retryingLibrary, isFalse);
    });

    test(
      'what waits for the catalog runs once, the first asked of a session only, and never another session',
      () async {
        fails();
        final exercises = build(libraryWait: wait)..userId = 'u1';
        await exercises.init();
        var first = 0;
        var second = 0;
        var stale = 0;
        exercises
          ..whenInitialized('u1', () => first++)
          // the same session asking again, as a resync does
          ..whenInitialized('u1', () => second++)
          // asked by a session that has ended
          ..whenInitialized('u0', () => stale++);
        expect(first, 0);

        answers();
        await exercises.retryLibrary();
        expect(first, 1);
        // a later notification runs nothing again
        exercises.showingMine = true;
        expect(first, 1);
        expect(second, 0);
        expect(stale, 0);
        // once in, a new ask runs at once
        exercises.whenInitialized('u1', () => second++);
        expect(second, 1);
      },
    );

    test('what waits is dropped when the session ends first, and the next session may wait', () async {
      fails();
      final exercises = build(libraryWait: wait)..userId = 'u1';
      await exercises.init();
      var ran = 0;
      exercises.whenInitialized('u1', () => ran++);

      exercises
        ..onSignOut()
        ..userId = 'u2';
      await exercises.init();
      var next = 0;
      exercises.whenInitialized('u2', () => next++);
      answers();
      await exercises.retryLibrary();
      expect(ran, 0);
      expect(next, 1);
    });

    test('nothing to retry once the catalog is in', () async {
      await sut.init();
      clearInteractions(library);

      expect(await sut.retryLibrary(), isTrue);
      verifyNever(library.getLibrary(cached: anyNamed('cached')));
    });
  });
}

class SocketLikeFailure implements Exception {
  const new();
}

extension on Map<String, DateTime> {
  DateTime? get(String id) => this[id];
}

class _MoveFake implements ExerciseMoveService {
  final calls = <(String, String, bool)>[];
  final mirrored = <(ExerciseMoveReport, String)>[];
  bool fails = false;
  bool mirrorFails = false;

  @override
  Future<ExerciseMoveReport> move(String sourceId, String targetId, {bool dryRun = false}) async {
    if (fails) throw StateError('refused');
    calls.add((sourceId, targetId, dryRun));
    return ExerciseMoveReport(
      sourceId: sourceId,
      targetId: targetId,
      dryRun: dryRun,
      workoutExercises: 3,
      templateExercises: 1,
      preferences: 1,
      preferencesDropped: 0,
      chartPreferences: 0,
      goals: 0,
      sourceDeleted: true,
    );
  }

  @override
  Future<void> mirror(ExerciseMoveReport report, {required String userId}) async {
    if (mirrorFails) throw StateError('locked');
    mirrored.add((report, userId));
  }
}

class _Unsent implements UnsentExerciseEditService {
  final marked = <String, Map<String, UnsentExerciseEdit>>{};
  bool fails = false;

  @override
  Future<Map<String, UnsentExerciseEdit>> read(String userId) async {
    if (fails) throw StateError('unreadable');
    return {...?marked[userId]};
  }

  @override
  Future<void> mark(String exerciseId, String userId, UnsentExerciseEdit? edit) async {
    final held = marked.putIfAbsent(userId, () => {});
    switch (edit) {
      case final UnsentExerciseEdit edit:
        held[exerciseId] = edit;
      case null:
        held.remove(exerciseId);
    }
  }
}

/// The app's name for the server's `409 name_taken`.
class _NameTaken implements Exception {
  const new();
}

class _Renames implements RemoteExerciseRenameService {
  final sent = <Exercise>[];

  /// Thrown by the next rename, and every one after, until cleared.
  Object? failure;

  /// What a rename waits for before it answers, when set as it starts.
  Future<void>? gate;

  @override
  Future<Exercise> renameExercise(Exercise exercise) async {
    if (failure case final Object failure) throw failure;
    if (gate case final Future<void> gate) await gate;
    sent.add(exercise);
    return exercise;
  }

  @override
  bool isNameTaken(Object error) => error is _NameTaken;
}
