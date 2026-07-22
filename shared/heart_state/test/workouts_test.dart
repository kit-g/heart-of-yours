import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_models/heart_models.dart' as models;
import 'package:heart_state/src/workouts.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

void main() {
  final local = MockWorkoutService();
  final remote = MockRemoteWorkoutService();
  late Workouts sut;

  // simple registry of a couple of real Exercises
  final bench = ex('Bench Press');
  final squat = ex('Squat');

  setUp(() {
    when(local.startWorkout(any, any)).thenAnswer((_) async {});
    when(local.finishWorkout(any, any)).thenAnswer((_) async {});
    when(local.startExercise(any, any)).thenAnswer((_) async {});
    when(local.removeExercise(any)).thenAnswer((_) async {});
    when(local.addSet(any, any)).thenAnswer((_) async {});
    when(local.removeSet(any)).thenAnswer((_) async {});
    when(local.storeMeasurements(any)).thenAnswer((_) async {});
    when(local.markSetAsComplete(any)).thenAnswer((_) async {});
    when(local.markSetAsIncomplete(any)).thenAnswer((_) async {});
    when(local.getActiveWorkout(any)).thenAnswer((_) async => null);
    when(local.getWorkout(any, any)).thenAnswer((_) async => null);
    when(local.getWorkoutHistory(any)).thenAnswer((_) async => <Workout>[]);
    when(local.storeWorkoutHistory(any, any)).thenAnswer((_) async {});
    when(local.deleteWorkout(any)).thenAnswer((_) async {});
    when(local.updateWorkout(workoutId: anyNamed('workoutId'), name: anyNamed('name'))).thenAnswer((_) async {});

    when(remote.getWorkouts(any, pageSize: anyNamed('pageSize'))).thenAnswer((_) async => <Workout>[]);
    when(remote.saveWorkout(any)).thenAnswer((inv) async => inv.positionalArguments.first as Workout);
    when(remote.editWorkout(any)).thenAnswer((inv) async => inv.positionalArguments.first as Workout);
    when(remote.deleteWorkout(any)).thenAnswer((_) async => true);

    sut = Workouts(service: local, remoteService: remote)..userId = 'u1';
  });

  tearDown(() {
    // nothing
  });

  group('Provider helpers', () {
    testWidgets('of(context) returns provided instance', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sut,
          child: Builder(
            builder: (context) {
              final got = Workouts.of(context);
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
              // watch triggers rebuilds when sut notifies
              final _ = Workouts.watch(context).hasActiveWorkout;
              builds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(builds, 1);

      await sut.startWorkout(name: 'Chest');
      await tester.pump();

      expect(builds, 2); // rebuilt due to notifyListeners in startWorkout
      verify(local.startWorkout(any, 'u1')).called(1);
    });
  });

  group('pointAt()', () {
    test('sets and then clears pointedAtExercise after 300ms, notifies twice', () async {
      final probe = ListenerProbe()..attach(sut);
      final id = bench.name;
      final future = sut.pointAt(id);

      expect(sut.pointedAtExercise, id);
      expect(probe.notifications, 1);

      await future; // awaits the 300ms delay that clears it
      expect(sut.pointedAtExercise, isNull);
      // one more notify due to clearing
      expect(probe.notifications, 2);
    });
  });

  group('start/finish/cancel/delete workout', () {
    test('startWorkout sets active, notifies, and calls service', () async {
      final probe = ListenerProbe()..attach(sut);

      await sut.startWorkout(name: 'Push');

      expect(sut.hasActiveWorkout, isTrue);
      expect(sut.activeWorkout, isNotNull);
      expect(probe.notifications, 1);
      verify(local.startWorkout(any, 'u1')).called(1);
    });

    test('finishActiveWorkout saves workout, clears active, notifies', () async {
      final probe = ListenerProbe()..attach(sut);
      await sut.startWorkout(name: 'Legs');
      probe.notifications = 0; // isolate

      final activeBefore = sut.activeWorkout!;
      await sut.finishActiveWorkout();

      // saveWorkout notifies twice (pre/post remote round-trip);
      // clearing active notifies once more.
      expect(probe.notifications, 3);
      expect(sut.activeWorkout, isNull);

      verify(local.finishWorkout(activeBefore, 'u1')).called(1);
      verify(remote.saveWorkout(activeBefore)).called(1);
    });

    test('cancelActiveWorkout removes locally and best-effort deletes remotely', () async {
      final probe = ListenerProbe()..attach(sut);
      await sut.startWorkout(name: 'Arms');
      probe.notifications = 0;
      final id = sut.activeWorkout!.id;

      await sut.cancelActiveWorkout();

      expect(sut.activeWorkout, isNull);
      expect(probe.notifications, 1);
      verify(local.deleteWorkout(id)).called(1);
      // active workouts may have been POST'd via attachImageToActiveWorkout;
      // cancel always tries the remote cleanup (errors swallowed).
      verify(remote.deleteWorkout(id)).called(1);
    });

    test('deleteWorkout removes by id, notifies, local+remote delete', () async {
      // prepare a workout in cache
      await sut.startWorkout(name: 'Temp');
      final id = sut.activeWorkout!.id;
      // switch off active so deleteWorkout path is different from cancel
      await sut.cancelActiveWorkout();

      final probe = ListenerProbe()..attach(sut);

      // clear previous interactions from cancelActiveWorkout
      reset(local);
      reset(remote);

      await sut.deleteWorkout(id);

      expect(sut.lookup(id), isNull);
      expect(probe.notifications, 1);
      verify(local.deleteWorkout(id)).called(1);
      verify(remote.deleteWorkout(id)).called(1);
    });
  });

  group('exercises and sets', () {
    test('startExercise adds WorkoutExercise, notifies and calls service', () async {
      await sut.startWorkout(name: 'Chest');
      final wid = sut.activeWorkout!.id;

      final probe = ListenerProbe()..attach(sut);
      await sut.startExercise(bench);

      expect(sut.activeWorkout!.toList(), isNotEmpty);
      expect(probe.notifications, 1);
      verify(local.startExercise(wid, any)).called(1);
    });

    test('addSet copies last set and calls service', () async {
      await sut.startWorkout(name: 'Chest');
      await sut.startExercise(bench);
      final we = sut.activeWorkout!.first;
      // have one set by default; add one more
      final probe = ListenerProbe()..attach(sut);
      await sut.addSet(we);

      expect(we.length, 2);
      expect(probe.notifications, 1); // via _forExercise(...)
      verify(local.addSet(we, any)).called(1);
    });

    test('removeSet removes and calls service', () async {
      await sut.startWorkout(name: 'Chest');
      await sut.startExercise(bench);
      final we = sut.activeWorkout!.first;
      final set = we.first;

      final probe = ListenerProbe()..attach(sut);
      await sut.removeSet(we, set);

      expect(we.contains(set), isFalse);
      expect(probe.notifications, 1);
      verify(local.removeSet(set)).called(1);
    });

    test('removeExercise removes and calls service', () async {
      await sut.startWorkout(name: 'Chest');
      await sut.startExercise(bench);
      final we = sut.activeWorkout!.first;

      final probe = ListenerProbe()..attach(sut);
      await sut.removeExercise(we);

      expect(sut.activeWorkout!.contains(we), isFalse);
      expect(probe.notifications, 1);
      verify(local.removeExercise(we)).called(1);
    });

    test('markSetAsComplete and nextIncomplete reflect state, notify and persist', () async {
      await sut.startWorkout(name: 'Chest');
      await sut.startExercise(bench);
      final we = sut.activeWorkout!.first;
      // ensure two sets
      await sut.addSet(we);
      final first = we.first;
      final second = we.elementAt(1);

      final probe = ListenerProbe()..attach(sut);
      await sut.markSetAsComplete(we, first);

      expect(first.isCompleted, isTrue);
      expect(probe.notifications, 1);
      verify(local.markSetAsComplete(first)).called(1);

      final next = sut.nextIncomplete;
      expect(next, isNotNull);
      expect(next!.$1, we);
      expect(next.$2, second);

      await sut.markSetAsIncomplete(we, first);
      expect(first.isCompleted, isFalse);
      verify(local.markSetAsIncomplete(first)).called(1);
    });

    test('storeMeasurements delegates to service', () async {
      await sut.startWorkout(name: 'Chest');
      await sut.startExercise(bench);
      final set = sut.activeWorkout!.first.first;

      await sut.storeMeasurements(set);
      verify(local.storeMeasurements(set)).called(1);
    });

    test('swap and append reorder exercises and notify', () async {
      await sut.startWorkout(name: 'Mix');
      await sut.startExercise(bench);
      await sut.startExercise(squat);
      final a = sut.activeWorkout!.first;
      final b = sut.activeWorkout!.elementAt(1);

      final probe = ListenerProbe()..attach(sut);
      await sut.swap(b, a);
      expect(sut.activeWorkout!.first, b);

      await sut.append(a);
      expect(sut.activeWorkout!.last, a);

      // swap + append each notify once
      expect(probe.notifications, 2);
    });

    test('renameWorkout calls local service and notifies', () async {
      await sut.startWorkout(name: 'Old');
      final id = sut.activeWorkout!.id;
      final probe = ListenerProbe()..attach(sut);

      await sut.renameWorkout('New');

      expect(sut.activeWorkout!.name, 'New');
      expect(probe.notifications, 1);
      verify(local.updateWorkout(workoutId: id, name: 'New')).called(1);
    });
  });

  group('init and history', () {
    test('init calls getActiveWorkout and sets active when available, notifies', () async {
      final w = Workout(name: 'FromLocal');
      when(local.getActiveWorkout('u1')).thenAnswer((_) async => w);

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.activeWorkout, isNotNull);
      expect(probe.notifications, 1);
    });

    test('initHistory: uses local if present, otherwise remote + store', () async {
      // case 1: local present
      final w1 = Workout(name: 'w1');
      when(local.getWorkoutHistory('u1')).thenAnswer((_) async => [w1]);
      when(local.getWorkoutGallery(userId: 'u1')).thenAnswer((_) async => ProgressGalleryResponse(images: []));
      when(
        remote.getWorkoutGallery(cursor: anyNamed('cursor')),
      ).thenAnswer(
        (_) async {
          return ProgressGalleryResponse.fromJson({'images': []});
        },
      );

      final probe1 = ListenerProbe()..attach(sut);
      await sut.initHistory();
      expect(sut.historyInitialized, isTrue);
      expect(sut.lookup(w1.id), w1);
      expect(probe1.notifications, 2);

      // reset and test remote path
      sut.onSignOut();
      sut.userId = 'u1';
      final w2 = Workout(name: 'w2');
      when(local.getWorkoutHistory('u1')).thenAnswer((_) async => <Workout>[]);
      when(local.getWorkoutGallery(userId: 'u1')).thenAnswer((_) async => ProgressGalleryResponse(images: []));
      when(remote.getWorkouts(any, pageSize: anyNamed('pageSize'))).thenAnswer((_) async => [w2]);

      final probe2 = ListenerProbe()..attach(sut);
      await sut.initHistory();

      verify(local.storeWorkoutHistory([w2], 'u1')).called(1);
      expect(sut.lookup(w2.id), w2);
      expect(probe2.notifications, 2);
    });

    test('fetchWorkout stores and notifies when found', () async {
      final w = Workout(name: 'fetched');
      when(local.getWorkout('u1', any)).thenAnswer((_) async => w);

      final probe = ListenerProbe()..attach(sut);
      await sut.fetchWorkout('wid');

      expect(sut.lookup('wid'), w);
      expect(probe.notifications, 1);
    });
  });

  group('history pagination', () {
    setUp(() {
      when(local.getWorkoutHistory('u1')).thenAnswer((_) async => <Workout>[]);
      when(local.getWorkoutGallery(userId: 'u1')).thenAnswer((_) async => ProgressGalleryResponse(images: []));
    });

    // `Page.hasMore` is authoritative; the next-page cursor the state sends is
    // the id of the last workout in the previous page (the backend's own cursor,
    // `cursorOf: (w) => w.id`).
    void whenFirstPage(List<Workout> items, {required bool more}) {
      when(
        remote.getWorkouts(any, pageSize: anyNamed('pageSize'), since: argThat(isNull, named: 'since')),
      ).thenAnswer((_) async => models.Page(items: items, hasMore: more));
    }

    void whenPageAfter(String since, List<Workout> items, {required bool more}) {
      when(
        remote.getWorkouts(any, pageSize: anyNamed('pageSize'), since: argThat(equals(since), named: 'since')),
      ).thenAnswer((_) async => models.Page(items: items, hasMore: more));
    }

    test('initHistory keeps paging when the backend reports more', () async {
      final w1 = Workout(name: 'w1');
      whenFirstPage([w1], more: true);

      await sut.initHistory();

      expect(sut.historyInitialized, isTrue);
      expect(sut.hasMoreHistory, isTrue);
      expect(sut.lookup(w1.id), w1);
    });

    test('initHistory stops when the backend reports no more (end of list)', () async {
      final w1 = Workout(name: 'w1');
      whenFirstPage([w1], more: false);

      await sut.initHistory();

      expect(sut.hasMoreHistory, isFalse);
    });

    test('loadMoreHistory pages off the last id as `since`, appends and advances', () async {
      final w1 = Workout(name: 'w1');
      final w2 = Workout(name: 'w2');
      whenFirstPage([w1], more: true);
      whenPageAfter(w1.id, [w2], more: true);

      await sut.initHistory();
      final probe = ListenerProbe()..attach(sut);

      await sut.loadMoreHistory();

      verify(
        remote.getWorkouts(any, pageSize: anyNamed('pageSize'), since: argThat(equals(w1.id), named: 'since')),
      ).called(1);
      verify(local.storeWorkoutHistory(argThat(contains(w2)), 'u1')).called(1);
      expect(sut.lookup(w2.id), w2);
      expect(sut.hasMoreHistory, isTrue);
      expect(sut.loadingMoreHistory, isFalse);
      // one notify entering the fetch, one leaving it
      expect(probe.notifications, 2);
    });

    test('loadMoreHistory stops at the last page and then no-ops', () async {
      final w1 = Workout(name: 'w1');
      final w2 = Workout(name: 'w2');
      whenFirstPage([w1], more: true);
      whenPageAfter(w1.id, [w2], more: false); // last page

      await sut.initHistory();
      await sut.loadMoreHistory();
      expect(sut.hasMoreHistory, isFalse);

      clearInteractions(remote);
      await sut.loadMoreHistory(); // guarded by !hasMore
      verifyNever(remote.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since')));
    });

    test('loadMoreHistory ignores a re-entrant call while a page is in flight', () async {
      final w1 = Workout(name: 'w1');
      whenFirstPage([w1], more: true);
      await sut.initHistory();

      // a page that never resolves until we say so
      final inFlight = Completer<Iterable<Workout>?>();
      when(
        remote.getWorkouts(any, pageSize: anyNamed('pageSize'), since: argThat(equals(w1.id), named: 'since')),
      ).thenAnswer((_) => inFlight.future);

      final first = sut.loadMoreHistory(); // takes the lock, awaits inFlight
      await sut.loadMoreHistory(); // re-entrant: returns immediately

      verify(
        remote.getWorkouts(any, pageSize: anyNamed('pageSize'), since: argThat(equals(w1.id), named: 'since')),
      ).called(1);

      inFlight.complete(models.Page(items: const [], hasMore: false));
      await first;
      expect(sut.hasMoreHistory, isFalse);
    });

    test('loadMoreHistory flags an error when the page fetch fails', () async {
      final w1 = Workout(name: 'w1');
      whenFirstPage([w1], more: true);
      await sut.initHistory();

      when(
        remote.getWorkouts(any, pageSize: anyNamed('pageSize'), since: argThat(equals(w1.id), named: 'since')),
      ).thenThrow(Exception('network down'));

      await sut.loadMoreHistory();

      expect(sut.historyPageError, isTrue);
      expect(sut.hasMoreHistory, isTrue); // still more to fetch — retry is offered
      expect(sut.loadingMoreHistory, isFalse);
    });

    test('retrying after a failed page clears the error and appends', () async {
      final w1 = Workout(name: 'w1');
      final w2 = Workout(name: 'w2');
      whenFirstPage([w1], more: true);
      await sut.initHistory();

      when(
        remote.getWorkouts(any, pageSize: anyNamed('pageSize'), since: argThat(equals(w1.id), named: 'since')),
      ).thenThrow(Exception('network down'));
      await sut.loadMoreHistory();
      expect(sut.historyPageError, isTrue);

      // the retry succeeds
      whenPageAfter(w1.id, [w2], more: true);
      await sut.loadMoreHistory();

      expect(sut.historyPageError, isFalse);
      expect(sut.lookup(w2.id), w2);
      expect(sut.hasMoreHistory, isTrue);
    });
  });

  group('misc', () {
    test('notifyOfActiveWorkout toggles flag and does NOT notify', () async {
      final probe = ListenerProbe()..attach(sut);
      await sut.startWorkout(name: 'any');
      expect(probe.notifications, 1);
      probe.notifications = 0;

      sut.notifyOfActiveWorkout();
      expect(probe.notifications, 0);
    });
  });
}
