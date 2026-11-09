import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The device's store, in memory: a plan is owed once its workout is synced.
class _Store implements LocalWorkoutPlanService {
  final plans = <String, Map<String, dynamic>>{};
  final sent = <String>{};
  final synced = <String>{};

  @override
  Future<void> storeWorkoutPlan(String workoutId, String userId, Map<String, dynamic> plan) async {
    plans[workoutId] = plan;
  }

  @override
  Future<List<({String workoutId, Map<String, dynamic> plan})>> getUnsentWorkoutPlans(String userId) async {
    return [
      for (final MapEntry(:key, :value) in plans.entries)
        if (synced.contains(key) && !sent.contains(key)) (workoutId: key, plan: value),
    ];
  }

  @override
  Future<void> markWorkoutPlanSent(String workoutId) async => sent.add(workoutId);
}

class _Server implements RemoteWorkoutPlanService {
  final received = <String, WorkoutPlan>{};

  /// Thrown by the next send, as the service throws a refusal's body.
  Object? refuse;

  @override
  Future<void> saveWorkoutPlan(String workoutId, WorkoutPlan plan) async {
    if (refuse case final refusal?) throw refusal;
    received[workoutId] = plan;
  }
}

void main() {
  late MockWorkoutService local;
  late MockRemoteWorkoutService remote;
  late _Store store;
  late _Server server;
  late Workouts workouts;
  late List<Object?> errors;

  const plan = WorkoutPlan({
    'templateId': 't1',
    'exercises': [
      {
        'sets': [
          {'weight': 100, 'setId': '01a1b7d4-c1db-7fc9-b20f-e61fcc3b5aa5'},
        ],
      },
    ],
  });

  setUp(() {
    local = MockWorkoutService();
    remote = MockRemoteWorkoutService();
    store = _Store();
    server = _Server();
    errors = [];
    workouts = Workouts(
      service: local,
      remoteService: remote,
      localPlans: store,
      remotePlans: server,
      onError: (error, {stacktrace}) => errors.add(error),
    )..userId = 'muffin';
    // the device marks a workout synced once the server's copy is stored
    when(local.storeWorkoutHistory(any, any)).thenAnswer((invocation) async {
      for (final workout in invocation.positionalArguments.first as Iterable<Workout>) {
        store.synced.add(workout.id);
      }
    });
    when(remote.saveWorkout(any)).thenAnswer((invocation) async => invocation.positionalArguments.first as Workout);
  });

  test("a program workout's plan is kept from the start", () async {
    await workouts.startWorkout(
      source: .program,
      template: Workout(name: 'Day A'),
      plan: plan,
    );
    expect(store.plans[workouts.activeWorkout!.id], plan.plan);
    expect(server.received, isEmpty, reason: 'the server has no workout to hang it on yet');
  });

  test('any other workout keeps no plan', () async {
    await workouts.startWorkout(source: .blank, name: 'Push');
    expect(store.plans, isEmpty);
  });

  test('finishing sends the plan once the workout is on the server', () async {
    await workouts.startWorkout(
      source: .program,
      template: Workout(name: 'Day A'),
      plan: plan,
    );
    final id = workouts.activeWorkout!.id;

    await workouts.saveWorkout(workouts.activeWorkout!);

    expect(server.received[id]?.plan, plan.plan);
    expect(store.sent, {id});
  });

  test('a plan that missed the finish goes with the next sync', () async {
    await workouts.startWorkout(
      source: .program,
      template: Workout(name: 'Day A'),
      plan: plan,
    );
    final id = workouts.activeWorkout!.id;
    server.refuse = StateError('offline');

    await workouts.saveWorkout(workouts.activeWorkout!);
    expect(store.sent, isEmpty);
    expect(errors, isNotEmpty);

    server.refuse = null;
    await workouts.sendWorkoutPlans();
    expect(store.sent, {id});
  });

  test('a plan the server refused as malformed is dropped, not retried forever', () async {
    store.plans['w1'] = plan.plan;
    store.synced.add('w1');
    server.refuse = {'code': 'invalid_plan'};

    await workouts.sendWorkoutPlans();

    expect(store.sent, {'w1'});
  });

  test('a workout the server does not have yet keeps its plan for later', () async {
    store.plans['w1'] = plan.plan;
    store.synced.add('w1');
    server.refuse = {'code': 'not_found'};

    await workouts.sendWorkoutPlans();

    expect(store.sent, isEmpty);
  });

  test('nothing is sent without an account', () async {
    workouts = Workouts(
      service: local,
      remoteService: remote,
      localPlans: store,
      remotePlans: server,
      remote: RemoteAccess(allowed: false),
    )..userId = 'anon';
    store.plans['w1'] = plan.plan;
    store.synced.add('w1');

    await workouts.sendWorkoutPlans();

    expect(server.received, isEmpty);
  });

  test('a plan that could not be kept never stops the workout', () async {
    workouts = Workouts(
      service: local,
      remoteService: remote,
      localPlans: _Broken(),
      remotePlans: server,
      onError: (error, {stacktrace}) => errors.add(error),
    )..userId = 'muffin';

    await workouts.startWorkout(
      source: .program,
      template: Workout(name: 'Day A'),
      plan: plan,
    );

    expect(workouts.hasActiveWorkout, isTrue);
    expect(errors, hasLength(1));
  });
}

class _Broken extends _Store {
  @override
  Future<void> storeWorkoutPlan(String workoutId, String userId, Map<String, dynamic> plan) async {
    throw StateError('disk full');
  }
}
