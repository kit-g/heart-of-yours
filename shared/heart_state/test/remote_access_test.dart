import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

/// The remote leg is closed — an anonymous session. Every state class keeps
/// working off the local store and never reaches for its remote service: what
/// it would have pushed stays behind, unsynced, for whenever an account comes.
void main() {
  const userId = 'anon-1';
  late RemoteAccess offline;

  setUp(() {
    offline = RemoteAccess(allowed: false);
  });

  group('Workouts', () {
    late MockWorkoutService local;
    late MockRemoteWorkoutService remote;
    late Workouts sut;

    setUp(() {
      local = MockWorkoutService();
      remote = MockRemoteWorkoutService();
      when(local.getWorkoutHistory(any)).thenAnswer((_) async => <Workout>[]);
      when(
        local.getWorkoutGallery(userId: anyNamed('userId')),
      ).thenAnswer((_) async => ProgressGalleryResponse(images: <WorkoutImage>[]));
      when(local.finishWorkout(any, any)).thenAnswer((_) async {});
      when(local.startWorkout(any, any)).thenAnswer((_) async {});
      when(local.deleteWorkout(any)).thenAnswer((_) async {});
      when(local.getWorkout(any, any)).thenAnswer((_) async => null);
      sut = Workouts(service: local, remoteService: remote, remote: offline)..userId = userId;
    });

    test('initHistory reads the mirror and has nothing further to page', () async {
      await sut.initHistory();

      expect(sut.historyInitialized, isTrue);
      expect(sut.hasMoreHistory, isFalse);
      verifyZeroInteractions(remote);
    });

    test('loadMoreHistory is a no-op', () async {
      await sut.loadMoreHistory();

      expect(sut.loadingMoreHistory, isFalse);
      verifyZeroInteractions(remote);
    });

    test('a finished workout is saved locally and never pushed', () async {
      await sut.startWorkout(name: 'Push');

      final saved = await sut.finishActiveWorkout();

      expect(saved, isNotNull);
      expect(sut.history.single.id, saved!.id);
      verify(local.finishWorkout(any, userId)).called(1);
      verifyZeroInteractions(remote);
    });

    test('an edit lands in the mirror through the unsynced write, not the synced one', () async {
      final workout = Workout(name: 'Legs')..finish(DateTime.timestamp());

      await sut.editWorkout(workout);

      verify(local.finishWorkout(workout, userId)).called(1);
      verifyNever(local.storeWorkoutHistory(any, any));
      verifyZeroInteractions(remote);
    });

    test('editing times patches the mirror copy in place', () async {
      final workout = Workout(name: 'Legs')..finish(DateTime.timestamp());
      await sut.editWorkout(workout);
      final start = DateTime.utc(2026, 1, 1, 9);

      final patched = await sut.editWorkoutTimes(workout.id, start: start);

      expect(patched?.start, start);
      expect(sut.lookup(workout.id)?.start, start);
      verifyZeroInteractions(remote);
    });

    test('deleting is local only', () async {
      await sut.deleteWorkout('w1');

      verify(local.deleteWorkout('w1')).called(1);
      verifyZeroInteractions(remote);
    });

    test('cancelling the active workout is local only', () async {
      await sut.startWorkout(name: 'Push');

      await sut.cancelActiveWorkout();

      expect(sut.hasActiveWorkout, isFalse);
      verifyZeroInteractions(remote);
    });

    /// A finished, synced workout as the mirror holds it after #85 stripped
    /// it: the row, none of its exercises. Online, the server's copy is asked
    /// for; offline there is nobody to ask.
    Workout stripped(String id) {
      return Workout.fromJson({
        'id': id,
        'start': '2026-08-21T10:00:00.000Z',
        'end': '2026-08-21T11:00:00.000Z',
        'exercises': [],
        'synced': 1,
      });
    }

    test('a stripped mirror row is not repaired from the server', () async {
      when(local.getWorkoutHistory(any)).thenAnswer((_) async => [stripped('w-stripped')]);

      await sut.initHistory();

      expect(sut.historyInitialized, isTrue);
      expect(sut.lookup('w-stripped'), isNotNull);
      verifyZeroInteractions(remote);
    });

    test('fetchWorkout answers a stripped mirror row rather than asking for it', () async {
      when(local.getWorkout(any, 'w-stripped')).thenAnswer((_) async => stripped('w-stripped'));

      expect(await sut.fetchWorkout('w-stripped'), isTrue);

      expect(sut.lookup('w-stripped'), isNotNull);
      verifyZeroInteractions(remote);
    });

    test('fetchWorkout answers false for what the mirror lacks', () async {
      expect(await sut.fetchWorkout('missing'), isFalse);
      verifyZeroInteractions(remote);
    });

    test('photos have nowhere to go', () async {
      await sut.startWorkout(name: 'Push');
      final image = (Uint8List(0), mimeType: 'image/png', name: 'a.png');

      expect(await sut.attachImageToActiveWorkout(image), isNull);
      expect(await sut.attachImageToWorkout(sut.activeWorkout!, image), isNull);
      verifyZeroInteractions(remote);
    });
  });

  group('Templates', () {
    late MockTemplateService local;
    late MockRemoteTemplateService remote;
    late MockRemoteConfigService config;
    late MockLocalTemplateFolderService localFolders;
    late MockApiTemplateFolderService remoteFolders;
    late MockRemoteTemplateFilingService filing;
    late Templates sut;

    setUp(() {
      local = MockTemplateService();
      remote = MockRemoteTemplateService();
      config = MockRemoteConfigService();
      localFolders = MockLocalTemplateFolderService();
      remoteFolders = MockApiTemplateFolderService();
      filing = MockRemoteTemplateFilingService();
      when(local.getTemplates(any)).thenAnswer((_) async => <Template>[]);
      when(localFolders.getFolders(any)).thenAnswer((_) async => <TemplateFolder>[]);
      when(config.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
      when(
        local.startTemplate(userId: anyNamed('userId'), order: anyNamed('order')),
      ).thenAnswer((_) async => tmpl(id: 't1'));
      when(local.updateTemplate(any)).thenAnswer((_) async {});
      when(local.deleteTemplate(any)).thenAnswer((_) async {});
      sut = Templates(
        remoteService: remote,
        service: local,
        configService: config,
        folderService: localFolders,
        remoteFolderService: remoteFolders,
        filingService: filing,
        remote: offline,
      )..userId = userId;
    });

    test('init loads the mirror and never asks the server', () async {
      await sut.init();

      verify(local.getTemplates(userId)).called(1);
      verifyZeroInteractions(remote);
      verifyZeroInteractions(remoteFolders);
    });

    test('a saved template stays local, under its own id', () async {
      await sut.add(ex('Bench Press'));
      sut.editable?.name = 'Push';

      await sut.saveEditable();

      expect(sut.single.id, 't1');
      expect(sut.single.local, isTrue);
      expect(sut.editable, isNull);
      verify(local.updateTemplate(any)).called(1);
      verifyZeroInteractions(remote);
    });

    test('deleting is local only', () async {
      await sut.add(ex('Bench Press'));
      await sut.saveEditable();

      await sut.delete(sut.single);

      expect(sut, isEmpty);
      verify(local.deleteTemplate('t1')).called(1);
      verifyZeroInteractions(remote);
    });

    test('folders are refused rather than requested', () async {
      await expectLater(sut.createFolder('Push'), throwsStateError);
      await expectLater(sut.moveToFolder(tmpl(id: 't2'), fldr()), throwsStateError);

      verifyZeroInteractions(remoteFolders);
      verifyZeroInteractions(filing);
    });
  });

  group('Goals', () {
    late MockLocalGoalService local;
    late MockGoalService remote;
    late Goals sut;

    Goal ladder({String? id}) {
      return Goal(
        id: id,
        metric: .topSetWeight,
        exerciseId: 'exercise-1',
        stages: [GoalStage(id: 's1', target: 100)],
      );
    }

    setUp(() {
      local = MockLocalGoalService();
      remote = MockGoalService();
      when(
        local.getTargetUserGoals(
          requesterId: anyNamed('requesterId'),
          targetUserId: anyNamed('targetUserId'),
          archived: anyNamed('archived'),
        ),
      ).thenAnswer((_) async => <Goal>[]);
      // a row written offline earlier — exactly what the push would send
      when(local.unsyncedGoals(any)).thenAnswer((_) async => [ladder(id: 'local-1')]);
      when(local.createGoal(any, any)).thenAnswer((_) async => ladder(id: 'local-1'));
      when(local.deleteGoal(any, any)).thenAnswer((_) async {});
      sut = Goals(service: local, remoteService: remote, remote: offline)..userId = userId;
    });

    test('init paints from the mirror, never pulls, never pushes what is pending', () async {
      await sut.init();

      expect(sut.initialized, isTrue);
      verifyZeroInteractions(remote);
    });

    test('a created goal is kept locally, unsynced, and not sent', () async {
      final created = await sut.create(ladder());

      expect(created.id, 'local-1');
      expect(sut.single.id, 'local-1');
      verify(local.createGoal(any, userId)).called(1);
      verifyZeroInteractions(remote);
    });

    test('removing is local only', () async {
      await sut.create(ladder());

      await sut.remove(sut.single);

      expect(sut, isEmpty);
      verify(local.deleteGoal('local-1', userId)).called(1);
      verifyZeroInteractions(remote);
    });

    test('pull is a no-op', () async {
      await sut.pull();

      verifyZeroInteractions(remote);
    });
  });

  group('Exercises', () {
    late MockExerciseService local;
    late MockRemoteExerciseService remote;
    late Exercises sut;

    setUp(() {
      local = MockExerciseService();
      remote = MockRemoteExerciseService();
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [ex('Bench Press')]));
      when(local.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
      when(local.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
      when(
        local.setExerciseUnit(
          exerciseName: anyNamed('exerciseName'),
          userId: anyNamed('userId'),
          unit: anyNamed('unit'),
        ),
      ).thenAnswer((_) async {});
      sut = Exercises(remoteService: remote, service: local, remote: offline)..userId = userId;
    });

    test('init serves the cache and never syncs', () async {
      expect(await sut.init(), isTrue);

      expect(sut.length, 1);
      expect(sut.isInitialized, isTrue);
      verifyZeroInteractions(remote);
    });

    test('an empty cache is an empty, initialized catalog — not a blocked one', () async {
      when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));

      expect(await sut.init(), isTrue);

      expect(sut, isEmpty);
      expect(sut.isInitialized, isTrue);
      verifyZeroInteractions(remote);
    });

    test('a locale change does not re-fetch', () async {
      await sut.init(locale: 'en');

      await sut.onLocaleChanged('fr');

      verifyZeroInteractions(remote);
    });

    test('a unit preference stays on the device', () async {
      final bench = ex('Bench Press');

      await sut.setUnit(bench, .metric);

      expect(sut.unitFor(bench.id), MeasurementUnit.metric);
      verify(local.setExerciseUnit(exerciseName: bench.id, userId: userId, unit: MeasurementUnit.metric)).called(1);
      verifyZeroInteractions(remote);
    });

    test('a custom exercise is made, edited and archived locally', () async {
      final custom = ex('Cable Fly');

      await sut.makeExercise(custom);
      expect(sut.lookup(custom.id), isNotNull);

      await sut.editExercise(custom);
      await sut.archive(custom);
      expect(sut.lookup(custom.id)?.isArchived, isTrue);

      await sut.unarchive(sut.lookup(custom.id)!);
      expect(sut.lookup(custom.id)?.isArchived, isFalse);

      verify(local.storeExercises(any, userId: userId)).called(4);
      verifyZeroInteractions(remote);
    });
  });
}
