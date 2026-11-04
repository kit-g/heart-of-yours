import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/workouts.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

/// The active workout's start, moved by hand (#530): a workout logged after
/// the fact began before Start was tapped. Every clock reads [Workouts.clockStart],
/// the finish saves what the workout holds, and a cold start reads the mirror.
void main() {
  final local = MockWorkoutService();
  final remote = MockRemoteWorkoutService();
  late Workouts sut;

  /// What the device was last told, as `(start, pauses, pausedAt)`.
  late (DateTime, List<WorkoutPause>, DateTime?)? stored;

  final bench = ex('Bench Press');
  final now = DateTime.timestamp();
  final start = now.subtract(const Duration(hours: 1));

  DateTime minute(int minutes) => start.add(Duration(minutes: minutes));

  setUp(() {
    when(local.startWorkout(any, any)).thenAnswer((_) async {});
    when(local.finishWorkout(any, any)).thenAnswer((_) async {});
    when(local.markSetAsComplete(any)).thenAnswer((_) async {});
    when(local.storeWorkoutHistory(any, any)).thenAnswer((_) async {});
    when(local.deleteWorkout(any)).thenAnswer((_) async {});
    when(remote.saveWorkout(any)).thenAnswer((inv) async => inv.positionalArguments.first as Workout);
    when(remote.deleteWorkout(any)).thenAnswer((_) async => true);

    stored = null;
    sut = Workouts(
      service: local,
      remoteService: remote,
      persistPauses: (_, _, _) async {},
      persistStart: (id, start, pauses, pausedAt) async {
        stored = (start, [...pauses], pausedAt);
      },
    )..userId = 'u1';
  });

  Future<void> begin() {
    final workout = Workout(name: 'Push')
      ..start = start
      ..add(bench);
    return sut.startWorkout(source: .blank, template: workout);
  }

  test('an earlier start moves the clock and is stored, and the finish saves it', () async {
    await begin();
    final earlier = start.subtract(const Duration(minutes: 40));
    var heard = 0;
    sut.addListener(() => heard++);

    await sut.moveStart(earlier.toLocal());

    expect(sut.activeWorkout!.start, earlier);
    expect(sut.activeWorkout!.start.isUtc, isTrue, reason: 'stored as the wire has it');
    expect(sut.clockStart, earlier, reason: 'what the lock screen and the watch count from');
    expect(sut.startMoved, isTrue);
    expect(heard, greaterThan(0), reason: 'the clocks hear of it');
    expect(stored!.$1, earlier);

    final end = minute(30);
    final saved = await sut.finishActiveWorkout(at: end);
    expect(saved!.start, earlier);
    expect(saved.end, end.toUtc());
    final sent = verify(remote.saveWorkout(captureAny)).captured.single as Workout;
    expect(sent.start, earlier, reason: 'sync carries it');
    expect(sut.startMoved, isFalse, reason: 'the next workout starts unmoved');
  });

  test('a start in the future is refused, and so is no workout at all', () async {
    await sut.moveStart(now.subtract(const Duration(hours: 2)));
    expect(stored, isNull);

    await begin();
    await sut.moveStart(DateTime.timestamp().add(const Duration(minutes: 5)));
    expect(sut.activeWorkout!.start, start);
    expect(sut.startMoved, isFalse);
    expect(stored, isNull);
  });

  test('a later start cuts the pauses it passes, and an open one begins there', () async {
    await begin();
    await sut.pause(at: minute(5));
    await sut.resume(at: minute(15));
    await sut.pause(at: minute(20));

    await sut.moveStart(minute(10));

    expect(sut.activeWorkout!.pauses.map((each) => (each.start, each.end)), [(minute(10), minute(15))]);
    expect(sut.pausedAt, minute(20), reason: 'an open pause after the start is left alone');
    expect(sut.clockStart, minute(15));
    expect(stored!.$2, hasLength(1));

    await sut.moveStart(minute(25));
    expect(sut.activeWorkout!.pauses, isEmpty);
    expect(sut.pausedAt, minute(25), reason: 'begun before the start, it begins at it');
    expect(stored!.$3, minute(25));
  });

  test('cancelling forgets the move', () async {
    await begin();
    await sut.moveStart(minute(-30));
    await sut.cancelActiveWorkout();
    expect(sut.startMoved, isFalse);
  });
}
