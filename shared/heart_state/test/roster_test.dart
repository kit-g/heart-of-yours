import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'test_utils.dart';

/// The server's side, in memory, paging by two.
class _Server implements RosterService {
  final clients = <ClientSummary>[];
  final former = <ClientSummary>[];
  final feed = <CoachFeedItem>[];
  final reviewed = <String, DateTime?>{};

  Object? refuse;
  var reads = 0;

  ({List<T> items, String? cursor}) _page<T>(List<T> all, String? cursor, {int size = 2}) {
    final from = int.parse(cursor ?? '0');
    final to = from + size;
    return (items: all.skip(from).take(size).toList(), cursor: to < all.length ? '$to' : null);
  }

  @override
  Future<({List<ClientSummary> items, String? cursor})> getClients({bool former = false, String? cursor}) async {
    reads++;
    if (refuse case final refusal?) throw refusal;
    return _page(former ? this.former : clients, cursor);
  }

  @override
  Future<void> markReviewed(String connectionId, {DateTime? at}) async {
    if (refuse case final refusal?) throw refusal;
    reviewed[connectionId] = at;
  }

  @override
  Future<({List<CoachFeedItem> items, String? cursor})> getCoachFeed({String? cursor}) async {
    if (refuse case final refusal?) throw refusal;
    return _page(feed, cursor);
  }

  final workouts = <Workout>[];
  final skips = <TrainingSkip>[];
  final plans = <String, WorkoutPlan>{};
  var workoutReads = 0;

  @override
  Future<({List<Workout> items, String? cursor})> getClientWorkouts(String studentId, {String? cursor}) async {
    if (refuse case final refusal?) throw refusal;
    return _page(workouts, cursor);
  }

  @override
  Future<List<TrainingSkip>> getClientSkips(String studentId) async => skips;

  @override
  Future<Workout> getClientWorkout(String studentId, String workoutId) async {
    workoutReads++;
    return workouts.firstWhere((each) => each.id == workoutId);
  }

  @override
  Future<WorkoutPlan?> getClientWorkoutPlan(String studentId, String workoutId) async => plans[workoutId];

  final logged = <String, List<Workout>>{};
  Object? refuseLog;

  @override
  Future<Workout> logClientWorkout(String studentId, Workout workout) async {
    if (refuseLog case final Object refusal) throw refusal;
    (logged[studentId] ??= []).add(workout);
    return Workout.fromJson({...workout.toMap(), 'loggedBy': 'whiskers', 'loggedByName': 'Whiskers'});
  }

  /// Keyed by workout: the first one stays, as the server keeps it.
  final loggedPlans = <String, WorkoutPlan>{};
  Object? refusePlan;

  @override
  Future<void> saveClientWorkoutPlan(String studentId, String workoutId, WorkoutPlan plan) async {
    if (refusePlan case final Object refusal) throw refusal;
    loggedPlans.putIfAbsent(workoutId, () => plan);
  }
}

Workout _workout(String id, DateTime start) {
  return Workout.fromJson({
    'id': id,
    'name': 'Day A',
    'start': start.toIso8601String(),
    'end': start.add(const Duration(hours: 1)).toIso8601String(),
    'exercises': [],
  });
}

ClientSummary _client(String name, {List<String> reasons = const [], List<DateTime> recent = const []}) {
  return ClientSummary(
    connectionId: 'c-$name',
    studentId: name,
    name: name,
    status: 'active',
    reasons: reasons,
    recent: recent,
  );
}

CoachFeedItem _item(String id) {
  return CoachFeedItem(kind: 'workout', id: id, studentId: 'muffin', at: DateTime.utc(2026, 11, 7));
}

void main() {
  late _Server server;
  late Roster roster;

  setUp(() {
    server = _Server();
    roster = Roster(service: server);
  });

  test('reads nothing until asked, and nothing with the remote leg closed', () async {
    expect(roster.status, CoachingStatus.idle);
    roster = Roster(service: server, remote: RemoteAccess(allowed: false));
    await roster.load();
    await roster.loadFeed();
    expect(server.reads, 0);
  });

  test('reads every page, in the order the server sorts', () async {
    server.clients.addAll([
      _client('muffin', reasons: ['note']),
      _client('biscuit', reasons: ['gap']),
      _client('pepper'),
    ]);

    await roster.load();

    expect(roster.status, CoachingStatus.loaded);
    expect(roster.clients.map((each) => each.name), ['muffin', 'biscuit', 'pepper']);
    expect(server.reads, 2);
  });

  test('the reasons on show: known ones in order, an unknown one carried after', () async {
    server.clients.addAll([
      _client('muffin', reasons: ['shrug', 'note']),
      _client('biscuit', reasons: ['ending', 'lighter']),
    ]);
    await roster.load();

    expect(roster.reasons, ['lighter', 'note', 'ending', 'shrug']);
    expect(roster.withReason('shrug').map((each) => each.name), ['muffin']);
  });

  test('a look clears what came before, and leaves what is still true to the server', () async {
    server.clients.addAll([
      _client('muffin', reasons: ['note', 'lighter']),
      _client('biscuit', reasons: ['gap', 'note', 'shrug']),
      _client('pepper'),
    ]);
    await roster.load();

    await roster.markReviewed(roster.clients.first);
    await roster.markReviewed(roster.clients.first);

    expect(server.reviewed.keys, {'c-muffin', 'c-biscuit'});
    expect(server.reviewed.values, everyElement(isNotNull));
    // a record holding a list compares the list by identity, so field by field
    expect(roster.clients.map((each) => each.name), ['biscuit', 'muffin', 'pepper']);
    expect(roster.clients.map((each) => each.reasons), [
      ['gap', 'shrug'],
      isEmpty,
      isEmpty,
    ]);
  });

  test('a look is counted once the server took it, and a refused one is not (#568)', () async {
    final reported = ReportedAnalytics();
    roster = Roster(
      service: server,
      analytics: Analytics(service: reported),
    );
    server.clients.add(_client('muffin', reasons: ['note']));
    await roster.load();

    await roster.markReviewed(roster.clients.single);
    server.refuse = refusedAs({'code': 'not_found'});
    await expectLater(roster.markReviewed(roster.clients.single), throwsA(isA<ServerRefusal>()));

    expect(reported.names, ['client_reviewed']);
  });

  test('a refused look changes nothing here', () async {
    server.clients.add(_client('muffin', reasons: ['note']));
    await roster.load();
    server.refuse = refusedAs({'code': 'not_found'});

    await expectLater(roster.markReviewed(roster.clients.single), throwsA(isRefusal('not_found')));
    expect(roster.clients.single.reasons, ['note']);
  });

  test('a failed read reports the error and says so', () async {
    final errors = [];
    roster = Roster(service: server, onError: (error, {stacktrace}) => errors.add(error));
    server.refuse = const ServerFailed();

    await roster.load();

    expect(roster.status, CoachingStatus.failed);
    expect(errors, hasLength(1));
  });

  test('former clients only when asked for', () async {
    server.former.add(_client('pepper'));
    expect(roster.formerStatus, CoachingStatus.idle);

    await roster.loadFormer();

    expect(roster.formerStatus, CoachingStatus.loaded);
    expect(roster.former.single.name, 'pepper');
  });

  test('the feed reads a page at a time, and a fresh read starts over', () async {
    server.feed.addAll([_item('a'), _item('b'), _item('c')]);

    await roster.loadFeed();
    expect(roster.feed.map((each) => each.id), ['a', 'b']);
    expect(roster.feedHasMore, isTrue);

    await roster.moreFeed();
    expect(roster.feed.map((each) => each.id), ['a', 'b', 'c']);
    expect(roster.feedHasMore, isFalse);

    await roster.moreFeed();
    await roster.loadFeed();
    expect(roster.feed.map((each) => each.id), ['a', 'b']);
  });

  test('signing out forgets everything', () async {
    server.clients.add(_client('muffin'));
    server.feed.add(_item('a'));
    await roster.load();
    await roster.loadFeed();

    roster.onSignOut();

    expect(roster.clients, isEmpty);
    expect(roster.feed, isEmpty);
    expect(roster.status, CoachingStatus.idle);
  });

  group('the last seven days', () {
    test("are the coach's days, oldest first, today last", () {
      final now = DateTime(2026, 11, 9, 8);
      final client = _client(
        'muffin',
        recent: [
          DateTime(2026, 11, 9, 7).toUtc(),
          DateTime(2026, 11, 7, 23, 30).toUtc(),
          DateTime(2026, 11, 7, 6).toUtc(),
          DateTime(2026, 11, 3, 0, 10).toUtc(),
          DateTime(2026, 11, 2, 23, 50).toUtc(),
        ],
      );

      expect(client.lastSevenDays(now), [true, false, false, false, true, false, true]);
    });

    test('nobody who never trained trained', () {
      expect(_client('muffin').lastSevenDays(DateTime(2026, 11, 9)), List.filled(7, false));
    });
  });

  group("a client's own record", () {
    test('their workouts page by page, and their skips newest first', () async {
      server.workouts.addAll([
        _workout('w3', DateTime.utc(2026, 11, 9)),
        _workout('w2', DateTime.utc(2026, 11, 8)),
        _workout('w1', DateTime.utc(2026, 11, 7)),
      ]);
      server.skips.addAll([
        TrainingSkip(at: DateTime.utc(2026, 11, 1)),
        TrainingSkip(at: DateTime.utc(2026, 11, 5)),
      ]);

      await roster.loadRecord('muffin');
      expect(roster.workoutsOf('muffin').map((each) => each.id), ['w3', 'w2']);
      expect(roster.hasMoreOf('muffin'), isTrue);
      expect(roster.skipsOf('muffin').map((each) => each.at.day), [5, 1]);

      await roster.moreRecord('muffin');
      expect(roster.workoutsOf('muffin').map((each) => each.id), ['w3', 'w2', 'w1']);
      expect(roster.hasMoreOf('muffin'), isFalse);
      expect(roster.recordStatus('muffin'), CoachingStatus.loaded);
    });

    test('a workout logged for them (#560) is theirs on the server, and first in their record', () async {
      server.workouts.add(_workout('w1', DateTime.utc(2026, 11, 7)));
      await roster.loadRecord('muffin');
      final workout = Workout(name: 'Day B, together')..start = DateTime.utc(2026, 11, 9);

      final logged = await roster.logFor('muffin', workout);

      expect(server.logged['muffin'], [workout]);
      expect(logged.loggedBy, 'whiskers');
      expect(roster.workoutsOf('muffin').map((each) => each.id), [workout.id, 'w1']);
    });

    test('a workout logged for them takes only what was done, as one logged for oneself does', () async {
      final bench = ex('Bench Press');
      final squat = ex('Squat');
      final workout = Workout(name: 'Push')..start = DateTime.utc(2026, 11, 9);
      workout.add(bench).first
        ..setMeasurements(reps: 8)
        ..isCompleted = true;
      // ticked with nothing in it, and typed but never ticked
      workout.first.add(ExerciseSet(bench)..isCompleted = true);
      workout.first.add(ExerciseSet(bench)..setMeasurements(reps: 5));
      workout.add(squat).first.isCompleted = true;

      await roster.logFor('muffin', workout);

      final sent = server.logged['muffin']!.single;
      expect(sent.map((exercise) => exercise.exercise.id), [bench.id], reason: 'an exercise of empty sets goes');
      expect(sent.single.map((set) => set.reps), [8]);
    });

    test("one logged for an earlier day still goes first: the record is the server's, newest id first", () async {
      server.workouts.add(_workout('w1', DateTime.utc(2026, 11, 7)));
      await roster.loadRecord('muffin');
      final workout = Workout(name: 'Day A, last week')..start = DateTime.utc(2026, 11, 2);

      await roster.logFor('muffin', workout);

      expect(roster.workoutsOf('muffin').map((each) => each.id), [workout.id, 'w1']);
    });

    test('a workout logged for them is counted after the server took it, as what was sent (#568)', () async {
      final reported = ReportedAnalytics();
      roster = Roster(
        service: server,
        analytics: Analytics(service: reported),
      );
      final bench = ex('Bench Press');
      final workout = Workout(name: 'Push')..start = DateTime.utc(2026, 11, 9);
      workout.add(bench).first
        ..setMeasurements(reps: 8)
        ..isCompleted = true;
      // typed but never ticked: not sent, so not counted
      workout.first.add(ExerciseSet(bench)..setMeasurements(reps: 5));
      workout.add(ex('Squat'));

      await roster.logFor('muffin', workout);

      expect(reported.parametersOf('workout_logged_for'), {'exercise_count': 1, 'set_count': 1});
    });

    test("a program session's plan goes with it, once the workout is in (heart-api#439)", () async {
      final workout = Workout(name: 'Day A')..start = DateTime.utc(2026, 11, 9);
      const plan = WorkoutPlan({'exercises': <Map<String, dynamic>>[]});

      await roster.logFor('muffin', workout, plan: plan);

      expect(server.logged['muffin'], [workout]);
      expect(server.loggedPlans, {workout.id: plan});
    });

    test('no plan sends none', () async {
      await roster.logFor('muffin', Workout()..start = DateTime.utc(2026, 11, 9));
      expect(server.loggedPlans, isEmpty);
    });

    test("a plan that doesn't land leaves it logged, and goes with the next try", () async {
      final errors = <Object>[];
      roster = Roster(service: server, onError: (error, {stacktrace}) => errors.add(error));
      final workout = Workout(name: 'Day A')..start = DateTime.utc(2026, 11, 9);
      const plan = WorkoutPlan({'exercises': <Map<String, dynamic>>[]});
      server.refusePlan = const ServerFailed();

      await roster.logFor('muffin', workout, plan: plan);

      expect(server.logged['muffin'], [workout], reason: 'a comparison lost, never a workout');
      expect(server.loggedPlans, isEmpty);
      expect(errors, [isA<ServerFailed>()]);

      server.refusePlan = null;
      await roster.loadRecord('muffin');
      await pumpEventQueue();
      expect(server.loggedPlans, {workout.id: plan});
    });

    test('a plan refused as malformed is let go: sending it again cannot help', () async {
      final workout = Workout(name: 'Day A')..start = DateTime.utc(2026, 11, 9);
      server.refusePlan = refusedAs({'code': 'invalid_plan'});
      await roster.logFor('muffin', workout, plan: const WorkoutPlan({'exercises': <Map<String, dynamic>>[]}));

      server.refusePlan = null;
      await roster.sendOwedPlans();
      expect(server.loggedPlans, isEmpty);
    });

    test('a log refused is thrown, and changes nothing here', () async {
      server.refuseLog = refusedAs({'code': 'forbidden'});

      expect(roster.logFor('muffin', Workout()), throwsA(isRefusal('forbidden')));
      await pumpEventQueue();
      expect(roster.workoutsOf('muffin'), isEmpty);
    });

    test('a refusal leaves it failed, and sign-out forgets it', () async {
      server.refuse = refusedAs({'code': 'forbidden'});
      await roster.loadRecord('muffin');
      expect(roster.recordStatus('muffin'), CoachingStatus.failed);

      roster.onSignOut();
      expect(roster.recordStatus('muffin'), CoachingStatus.idle);
    });

    test('a review reads the plan once, and a workout already read is not read again', () async {
      server.workouts.add(_workout('w1', DateTime.utc(2026, 11, 7)));
      await roster.loadRecord('muffin');

      final review = await roster.review('muffin', 'w1');
      expect(review.hasPlan, isFalse);
      expect(identical(await roster.review('muffin', 'w1'), review), isTrue);
      expect(server.workoutReads, 0);
    });
  });
}
