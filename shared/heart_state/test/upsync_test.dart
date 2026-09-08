import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

/// A ledger and a debt that live in memory, the way the database keeps them.
class _Ledger extends Fake implements LocalUpsyncService {
  final owed = <String>{};
  final entries = <String, Map<UpsyncResource, Map<String, UpsyncOutcome>>>{};
  final rekeys = <(String, String)>[];
  final exerciseMerges = <(String, String)>[];
  final folderMerges = <(String, String)>[];

  /// What a merge does to the store, for the test to emulate on its mocks.
  void Function(String from, String to)? onMergeExercise;
  void Function(String from, String to)? onMergeFolder;

  @override
  Future<void> rekeyUser(String from, String to) async => rekeys.add((from, to));

  @override
  Future<void> owe(String userId) async => owed.add(userId);

  @override
  Future<bool> isOwed(String userId) async => owed.contains(userId);

  @override
  Future<Map<UpsyncResource, Map<String, UpsyncOutcome>>> ledger(String userId) async {
    return {
      for (final MapEntry(:key, :value) in (entries[userId] ?? {}).entries) key: Map.of(value),
    };
  }

  @override
  Future<void> record(String userId, UpsyncResource resource, String id, UpsyncOutcome outcome) async {
    entries.putIfAbsent(userId, () => {}).putIfAbsent(resource, () => {})[id] = outcome;
  }

  @override
  Future<void> settle(String userId) async {
    owed.remove(userId);
    entries.remove(userId);
  }

  @override
  Future<void> mergeExercise(String userId, {required String from, required String to}) async {
    exerciseMerges.add((from, to));
    onMergeExercise?.call(from, to);
  }

  @override
  Future<void> mergeFolder(String userId, {required String from, required String to}) async {
    folderMerges.add((from, to));
    onMergeFolder?.call(from, to);
  }
}

/// A server that answers every create in order, remembers what it was sent,
/// and can be told to be unreachable from a given call on.
class _Server extends Fake implements UpsyncService {
  final calls = <(UpsyncResource, String)>[];

  /// Ids the account already had: answered `200`, under the same id.
  final existing = <String>{};

  /// Name merges: the id sent → the account's own id by that name.
  final merged = <String, String>{};

  /// Refusals, by id sent.
  final refused = <String, Map<String, dynamic>>{};

  /// From this many calls on, the network is gone.
  int? deadAfter;

  void _reach(UpsyncResource resource, String id) {
    if (deadAfter case int n when calls.length >= n) throw const SocketException('offline');
    calls.add((resource, id));
    if (refused[id] case Map<String, dynamic> refusal) throw refusal;
  }

  @override
  Future<Replayed<Exercise>> replayExercise(Exercise exercise) async {
    _reach(.exercise, exercise.id);
    return switch (merged[exercise.id]) {
      String theirs => (row: Exercise.fromJson({...exercise.toMap(), 'id': theirs}), created: false),
      null => (row: exercise, created: !existing.contains(exercise.id)),
    };
  }

  @override
  Future<void> replayUnitPreference(String exerciseId, MeasurementUnit unit) async => _reach(.unit, exerciseId);

  @override
  Future<Replayed<TemplateFolder>> replayFolder(TemplateFolder folder) async {
    _reach(.folder, folder.id!);
    return switch (merged[folder.id]) {
      String theirs => (row: folder.copyWith(id: theirs), created: false),
      null => (row: folder, created: !existing.contains(folder.id)),
    };
  }

  @override
  Future<Replayed<Template>> replayTemplate(Template template) async {
    _reach(.template, template.id);
    return (row: template, created: !existing.contains(template.id));
  }

  @override
  Future<Replayed<Workout>> replayWorkout(Workout workout) async {
    _reach(.workout, workout.id);
    return (row: workout, created: !existing.contains(workout.id));
  }

  @override
  Future<Replayed<Goal>> replayGoal(Goal goal) async {
    _reach(.goal, goal.id!);
    return (row: goal, created: !existing.contains(goal.id));
  }
}

class SocketException implements Exception {
  final String message;

  const new(this.message);
}

void main() {
  const uid = 'acct-1';
  late _Ledger ledger;
  late _Server server;
  late MockExerciseService exercises;
  late MockLocalTemplateFolderService folders;
  late MockTemplateService templates;
  late MockWorkoutService workouts;
  late MockLocalGoalService goals;
  late RemoteAccess access;
  late List<Object> errors;
  late int completions;
  late Upsync sut;

  final bench = ex('Bench Press');
  final custom = Exercise(name: 'Cable Crossover, low', category: .machine, target: .chest, isMine: true);
  final unitOn = ex('Squat');

  Workout finished(String name) {
    final w = Workout(name: name);
    w.append(wEx(bench));
    w.finish(DateTime.timestamp());
    return w;
  }

  Goal goal(String id) {
    return Goal(
      id: id,
      metric: .topSetWeight,
      exerciseId: custom.id,
      stages: [GoalStage(id: '$id-s0', target: 100)],
    );
  }

  /// One of everything, all of it pending. The same rows on every read, as a
  /// store would answer — a merge is the one thing that changes what it holds,
  /// and the ledger fake mirrors that below.
  void seedStore({List<Workout>? pending}) {
    final history = pending ?? [finished('Monday'), finished('Tuesday')];
    when(exercises.getExercises(userId: uid)).thenAnswer((_) async => (null, [bench, custom]));
    when(exercises.getExerciseUnits(uid)).thenAnswer((_) async => {unitOn.id: MeasurementUnit.imperial});
    when(folders.getFolders(uid)).thenAnswer((_) async => [fldr(id: 'f1', name: 'Push')]);
    when(templates.getTemplates(uid)).thenAnswer(
      (_) async => [
        tmpl(id: 't1', name: 'Push day', exercises: [wEx(custom)]),
        // the draft an editor never finished: not a template the user has
        tmpl(id: 'draft'),
      ],
    );
    when(workouts.getWorkoutHistory(uid)).thenAnswer((_) async => history);
    when(goals.unsyncedGoals(uid)).thenAnswer((_) async => [goal('g1')]);

    // after a merge the store holds the server's row and not the one it merged
    ledger.onMergeExercise = (from, to) {
      final theirs = Exercise.fromJson({...custom.toMap(), 'id': to});
      when(exercises.getExercises(userId: uid)).thenAnswer((_) async => (null, [bench, theirs]));
    };
    ledger.onMergeFolder = (from, to) {
      when(folders.getFolders(uid)).thenAnswer((_) async => [fldr(id: to, name: 'push')]);
    };
  }

  setUp(() {
    ledger = _Ledger();
    server = _Server();
    exercises = MockExerciseService();
    folders = MockLocalTemplateFolderService();
    templates = MockTemplateService();
    workouts = MockWorkoutService();
    goals = MockLocalGoalService();
    access = RemoteAccess();
    errors = [];
    completions = 0;
    sut = Upsync(
      local: ledger,
      remote: server,
      exercises: exercises,
      folders: folders,
      templates: templates,
      workouts: workouts,
      goals: goals,
      access: access,
      onError: (error, {stacktrace}) => errors.add(error),
      onComplete: () => completions++,
    );
    when(exercises.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(folders.storeFolder(any, any)).thenAnswer((_) async {});
    when(templates.storeTemplates(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(templates.deleteTemplate(any)).thenAnswer((_) async {});
    when(workouts.storeWorkoutHistory(any, any)).thenAnswer((_) async {});
    when(goals.reconcileGoalId(any, any, any)).thenAnswer((_) async {});
  });

  group('claim', () {
    test('link: the uid stays, nothing moves, the replay is owed and the leg held', () async {
      await sut.claim(from: uid, to: uid);

      expect(ledger.rekeys, isEmpty);
      expect(ledger.owed, {uid});
      expect(access.replaying, isTrue);
      expect(access.allowed, isFalse);
    });

    test('existing account: the rows move onto the new uid before it is owed', () async {
      await sut.claim(from: 'anon-1', to: uid);

      expect(ledger.rekeys, [('anon-1', uid)]);
      expect(ledger.owed, {uid});
      expect(access.replaying, isTrue);
    });
  });

  group('restore', () {
    test('a launch under a uid still owed holds the leg; one that is not opens it', () async {
      ledger.owed.add(uid);
      expect(await sut.restore(uid), isTrue);
      expect(access.replaying, isTrue);

      expect(await sut.restore('other'), isFalse);
      expect(access.replaying, isFalse);
    });
  });

  group('run', () {
    test('replays every pending row exactly once, in the contract\'s order, then opens the leg', () async {
      seedStore();
      await sut.claim(from: uid, to: uid);
      expect(access.allowed, isFalse);

      await sut.run(uid);

      expect(server.calls.map((each) => each.$1), [
        UpsyncResource.exercise,
        UpsyncResource.unit,
        UpsyncResource.folder,
        UpsyncResource.template,
        UpsyncResource.workout,
        UpsyncResource.workout,
        UpsyncResource.goal,
      ]);
      // the library row is the CDN's, the draft is nobody's
      expect(server.calls.map((each) => each.$2), isNot(contains(bench.id)));
      expect(server.calls.map((each) => each.$2), isNot(contains('draft')));
      expect(server.calls.toSet(), hasLength(server.calls.length), reason: 'no row twice');

      expect(sut.status, UpsyncStatus.done);
      expect(sut.report, (uploaded: 7, existing: 0, skipped: 0));
      expect(sut.done, 7);
      expect(sut.total, 7);
      expect(access.replaying, isFalse);
      expect(access.allowed, isTrue);
      expect(ledger.owed, isEmpty, reason: 'settled');
      expect(completions, 1);
      expect(errors, isEmpty);
    });

    test('each confirmed row is written back as the server\'s copy', () async {
      seedStore();
      await sut.claim(from: uid, to: uid);

      await sut.run(uid);

      final stored = verify(exercises.storeExercises(captureAny, userId: uid)).captured.single as Iterable<Exercise>;
      expect(stored.single.id, custom.id);
      expect(stored.single.isMine, isTrue);
      verify(folders.storeFolder(any, uid)).called(1);
      verify(templates.storeTemplates(any, userId: uid)).called(1);
      verifyNever(templates.deleteTemplate(any));
      verify(workouts.storeWorkoutHistory(any, uid)).called(2);
      verify(goals.reconcileGoalId('g1', any, uid)).called(1);
    });

    test('into an account with history: 200s are counted as already there', () async {
      seedStore();
      server.existing.addAll(['t1', 'g1']);
      await sut.claim(from: 'anon-1', to: uid);

      await sut.run(uid);

      expect(sut.report, (uploaded: 5, existing: 2, skipped: 0));
    });

    test('a name-merged custom is rewritten before anything downstream is sent', () async {
      seedStore();
      server.merged[custom.id] = 'theirs';
      await sut.claim(from: 'anon-1', to: uid);

      await sut.run(uid);

      expect(ledger.exerciseMerges, [(custom.id, 'theirs')]);
      final stored = verify(exercises.storeExercises(captureAny, userId: uid)).captured.single as Iterable<Exercise>;
      expect(stored.single.id, 'theirs');
      // the merge landed before the first downstream call went out
      final mergeAt = server.calls.indexWhere((each) => each.$1 == UpsyncResource.exercise);
      final firstDownstream = server.calls.indexWhere((each) => each.$1 == UpsyncResource.template);
      expect(mergeAt, lessThan(firstDownstream));
      expect(sut.report.existing, 1);
    });

    test('a merge moves the ids the steps behind it have not read yet', () async {
      // the store's unit preference is on the custom that merges, and the real
      // `mergeExercise` moves it: `UPDATE OR REPLACE exercise_details SET
      // exercise_id = ?`. Plan the run up front and the units step still holds
      // the id the merge just deleted.
      seedStore();
      when(exercises.getExerciseUnits(uid)).thenAnswer((_) async => {custom.id: MeasurementUnit.imperial});
      server.merged[custom.id] = 'theirs';
      ledger.onMergeExercise = (from, to) {
        final theirs = Exercise.fromJson({...custom.toMap(), 'id': to});
        when(exercises.getExercises(userId: uid)).thenAnswer((_) async => (null, [bench, theirs]));
        when(exercises.getExerciseUnits(uid)).thenAnswer((_) async => {to: MeasurementUnit.imperial});
      };
      await sut.claim(from: 'anon-1', to: uid);

      await sut.run(uid);

      final units = server.calls.where((each) => each.$1 == UpsyncResource.unit).map((each) => each.$2);
      expect(units, ['theirs']);
      // heart-of-yours#113 stress run: the pre-merge id reached the server,
      // which answered 500 on a foreign key, and the backup stopped at row 26
      // of 358 with 332 rows never attempted
      expect(units, isNot(contains(custom.id)));
      expect(sut.status, UpsyncStatus.done);
    });

    test('a name-merged folder refiles its templates', () async {
      seedStore();
      server.merged['f1'] = 'their-folder';
      await sut.claim(from: 'anon-1', to: uid);

      await sut.run(uid);

      expect(ledger.folderMerges, [('f1', 'their-folder')]);
    });

    test('a template the server re-minted has its old row dropped before the copy is stored', () async {
      seedStore();
      // a pre-cutover timestamp id is left off the wire and the server mints
      sut = Upsync(
        local: ledger,
        remote: _RemintingServer(),
        exercises: exercises,
        folders: folders,
        templates: templates,
        workouts: workouts,
        goals: goals,
        access: access,
      );
      await sut.claim(from: uid, to: uid);
      // once the old row is dropped the store answers with the server's copy
      when(templates.deleteTemplate('t1')).thenAnswer((_) async {
        when(templates.getTemplates(uid)).thenAnswer(
          (_) async => [
            Template.fromJson({...tmpl(id: 't1', name: 'Push day').toMap(), 'id': 'server-t1'}),
          ],
        );
      });

      await sut.run(uid);

      verify(templates.deleteTemplate('t1')).called(1);
      final stored = verify(templates.storeTemplates(captureAny, userId: uid)).captured.single as Iterable<Template>;
      expect(stored.single.id, 'server-t1');
      expect(sut.status, UpsyncStatus.done);
      expect(ledger.entries[uid], isNull, reason: 'settled');
    });

    test('an unreachable server stops the run where it is, retryable, with the leg still held', () async {
      seedStore();
      server.deadAfter = 4;
      await sut.claim(from: uid, to: uid);

      await sut.run(uid);

      expect(sut.status, UpsyncStatus.failed);
      expect(sut.done, 4);
      expect(sut.total, 7);
      expect(access.allowed, isFalse);
      expect(ledger.owed, {uid});
      expect(errors, hasLength(1));
      expect(completions, 0);
    });

    test('a resumed run picks up after the last confirmed row and posts nothing twice', () async {
      seedStore();
      server.deadAfter = 5;
      await sut.claim(from: uid, to: uid);
      await sut.run(uid);
      expect(sut.status, UpsyncStatus.failed);

      server.deadAfter = null;
      await sut.retry();

      expect(sut.status, UpsyncStatus.done);
      expect(server.calls.toSet(), hasLength(7), reason: 'seven distinct rows across both attempts');
      expect(server.calls, hasLength(7), reason: 'and seven calls: nothing was posted twice');
      expect(sut.report, (uploaded: 7, existing: 0, skipped: 0));
      expect(sut.done, 7);
      expect(access.allowed, isTrue);
    });

    test('a fresh notifier resumes from the ledger — an interrupted launch', () async {
      seedStore();
      server.deadAfter = 3;
      await sut.claim(from: uid, to: uid);
      await sut.run(uid);

      // the app relaunches: new notifier, same store
      server.deadAfter = null;
      final relaunched = Upsync(
        local: ledger,
        remote: server,
        exercises: exercises,
        folders: folders,
        templates: templates,
        workouts: workouts,
        goals: goals,
        access: access,
      );
      expect(await relaunched.restore(uid), isTrue);
      await relaunched.run(uid);

      expect(relaunched.status, UpsyncStatus.done);
      expect(server.calls, hasLength(7));
      expect(relaunched.report, (uploaded: 7, existing: 0, skipped: 0), reason: 'the count spans both attempts');
    });

    test('a refusal is skipped and reported, and the run goes on', () async {
      seedStore();
      server.refused['g1'] = {'error': 'bad request', 'code': 'goal_limit'};
      await sut.claim(from: uid, to: uid);

      await sut.run(uid);

      expect(sut.status, UpsyncStatus.done);
      expect(sut.report, (uploaded: 6, existing: 0, skipped: 1));
      expect(errors, hasLength(1));
      verifyNever(goals.reconcileGoalId(any, any, any));
    });

    test('an id that belongs to someone else is skipped and never retried', () async {
      final monday = finished('Monday');
      seedStore(pending: [monday, finished('Tuesday')]);
      server.refused[monday.id] = {'error': 'forbidden', 'code': 'id_taken'};
      await sut.claim(from: uid, to: uid);

      // stopped by a dead network right after, so the second run is a resume
      server.deadAfter = 6;
      await sut.run(uid);
      expect(sut.status, UpsyncStatus.failed);
      server.deadAfter = null;
      await sut.run(uid);

      expect(server.calls.where((each) => each.$2 == monday.id), hasLength(1));
      expect(sut.status, UpsyncStatus.done);
      expect(sut.report, (uploaded: 6, existing: 0, skipped: 1));
    });

    test('a reference the account does not have skips one row, not the backup', () async {
      // heart-api 593ea80 maps a Postgres foreign-key violation onto a code.
      // Before it the same case arrived as a 500, which reads as an outage:
      // the run stopped where it stood and everything behind it went untried.
      seedStore();
      server.refused[unitOn.id] = {
        'error': 'not found',
        'code': 'unknown_exercise',
        'message': 'Exercise #${unitOn.id} not found',
      };
      await sut.claim(from: 'anon-1', to: uid);

      await sut.run(uid);

      expect(sut.status, UpsyncStatus.done);
      expect(sut.report.skipped, 1);
      // the rows behind the refused one all went out
      expect(server.calls.map((each) => each.$1), contains(UpsyncResource.workout));
      expect(server.calls.map((each) => each.$1), contains(UpsyncResource.goal));
    });

    test('a row written during the run is picked up by the next pass', () async {
      final monday = finished('Monday');
      final wednesday = finished('Wednesday');
      seedStore(pending: [monday]);
      var reads = 0;
      when(workouts.getWorkoutHistory(uid)).thenAnswer((_) async {
        reads++;
        return switch (reads) {
          1 => [monday],
          _ => [monday, wednesday],
        };
      });
      await sut.claim(from: uid, to: uid);

      await sut.run(uid);

      expect(server.calls.where((each) => each.$1 == UpsyncResource.workout).map((each) => each.$2), [
        monday.id,
        wednesday.id,
      ]);
      // six rows in the store at the start, and the one written under way
      expect(sut.report.uploaded, 7);
    });

    test('nothing owed: a no-op that opens the leg', () async {
      access.replaying = true;

      await sut.run(uid);

      expect(sut.status, UpsyncStatus.idle);
      expect(access.replaying, isFalse);
      expect(server.calls, isEmpty);
      expect(completions, 0);
    });

    test('concurrent callers share one run', () async {
      seedStore();
      await sut.claim(from: uid, to: uid);

      await Future.wait([sut.run(uid), sut.run(uid)]);

      expect(server.calls, hasLength(7));
    });

    test('signing out mid-run abandons it and confirms nothing more', () async {
      seedStore();
      await sut.claim(from: uid, to: uid);
      final gate = Completer<void>();
      when(workouts.storeWorkoutHistory(any, any)).thenAnswer((_) => gate.future);

      final run = sut.run(uid);
      await Future<void>.delayed(Duration.zero);
      while (server.calls.length < 5) {
        await Future<void>.delayed(Duration.zero);
      }
      sut.onSignOut();
      gate.complete();
      await run;

      expect(sut.status, UpsyncStatus.idle);
      expect(server.calls, hasLength(5));
      expect(ledger.owed, {uid}, reason: 'still owed to that account for next time');
      expect(completions, 0);
    });

    test('dismiss puts the line away, and only a finished or failed one', () async {
      seedStore();
      await sut.claim(from: uid, to: uid);
      var notified = 0;
      sut.addListener(() => notified++);
      sut.dismiss();
      expect(notified, 0);

      await sut.run(uid);
      expect(sut.status, UpsyncStatus.done);
      sut.dismiss();
      expect(sut.status, UpsyncStatus.idle);
    });
  });
}

/// A server that mints its own id for the one template it is sent — what a
/// pre-cutover timestamp id gets.
class _RemintingServer extends _Server {
  @override
  Future<Replayed<Template>> replayTemplate(Template template) async {
    _reach(.template, template.id);
    final row = Template.fromJson({...template.toMap(), 'id': 'server-t1'});
    return (row: row, created: true);
  }
}
