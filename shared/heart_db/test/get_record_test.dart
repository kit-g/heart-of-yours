import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_db/src/sql.dart' as sql;
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'utils.dart';

/// The records fold behind [LocalDatabase.getRecord]: every record must be the
/// set it happened on — value, its own companions, its workout and date —
/// never independent maxima glued together (which is exactly what the old
/// per-metric query did).
void main() {
  late LocalDatabase local;
  final db = MockDatabase();

  setUp(() async {
    local = await LocalDatabase.init(other: db);
  });

  Map<String, dynamic> row({
    num? weight,
    num? reps,
    num? duration,
    num? distance,
    String workoutId = 'w1',
    String start = '2026-01-10T10:00:00Z',
  }) {
    return {
      'weight': weight,
      'reps': reps,
      'duration': duration,
      'distance': distance,
      'workout_id': workoutId,
      'start': start,
    };
  }

  void stub(String exerciseName, List<Map<String, dynamic>> rows) {
    when(db.rawQuery(sql.recordSets, ['user-1', exerciseName])).thenAnswer((_) async => rows);
  }

  group('strength', () {
    test('each record carries its own set, workout and date', () async {
      final ex = exercise(name: 'Bench', category: 'Barbell');
      stub(ex.id, [
        // heaviest single, low reps
        row(weight: 100, reps: 3, workoutId: 'w1', start: '2026-01-01T10:00:00Z'),
        // best volume and best e1rm live on a different set
        row(weight: 90, reps: 10, workoutId: 'w2', start: '2026-02-01T10:00:00Z'),
        row(weight: 60, reps: 15, workoutId: 'w3', start: '2026-03-01T10:00:00Z'),
      ]);

      final records = (await local.getRecord('user-1', ex))!;

      // the old query would have reported weight 100 next to reps 15 —
      // a set that never happened
      expect(records['heaviest'], {'weight': 100.0, 'reps': 3, 'workoutId': 'w1', 'at': '2026-01-01T10:00:00Z'});
      expect(
        records['bestVolume'],
        {'value': 900.0, 'weight': 90.0, 'reps': 10, 'workoutId': 'w2', 'at': '2026-02-01T10:00:00Z'},
      );

      final oneRepMax = records['oneRepMax'] as Map;
      expect(oneRepMax['workoutId'], 'w2'); // 90×10 estimates higher than 100×3
      expect(oneRepMax['value'], closeTo(120.0, .1)); // 90 / (1.0278 − .278)

      expect(records['sessions'], 3);
      expect(records['firstAt'], '2026-01-01T10:00:00Z');
      expect(records['totalVolume'], 100.0 * 3 + 90 * 10 + 60 * 15);
    });

    test('rep maxes keep the best weight per rep count, first achievement wins ties', () async {
      final ex = exercise(name: 'Squat', category: 'Barbell');
      stub(ex.id, [
        row(weight: 100, reps: 5, workoutId: 'w1', start: '2026-01-01T10:00:00Z'),
        // same weight at the same reps later must not steal the record
        row(weight: 100, reps: 5, workoutId: 'w2', start: '2026-02-01T10:00:00Z'),
        row(weight: 110, reps: 3, workoutId: 'w2', start: '2026-02-01T10:00:00Z'),
        // 11+ reps stay out of the table
        row(weight: 40, reps: 20, workoutId: 'w3', start: '2026-03-01T10:00:00Z'),
      ]);

      final records = (await local.getRecord('user-1', ex))!;
      expect(records['repMaxes'], [
        {'reps': 3, 'weight': 110.0, 'workoutId': 'w2', 'at': '2026-02-01T10:00:00Z'},
        {'reps': 5, 'weight': 100.0, 'workoutId': 'w1', 'at': '2026-01-01T10:00:00Z'},
      ]);
    });

    test('a heaviest set with null reps still counts, without inventing reps', () async {
      final ex = exercise(name: 'Press', category: 'Dumbbell');
      stub(ex.id, [
        row(weight: 30, reps: 8, workoutId: 'w1'),
        row(weight: 40, reps: null, workoutId: 'w2'),
      ]);

      final records = (await local.getRecord('user-1', ex))!;
      expect((records['heaviest'] as Map)['weight'], 40.0);
      expect((records['heaviest'] as Map).containsKey('reps'), isFalse);
      // volume/e1rm records need reps, so they come from the 30×8 set
      expect((records['bestVolume'] as Map)['weight'], 30.0);
    });
  });

  group('other categories', () {
    test('reps only', () async {
      final ex = exercise(name: 'Pull Up', category: 'Reps Only');
      stub(ex.id, [
        row(reps: 10, workoutId: 'w1', start: '2026-01-01T10:00:00Z'),
        row(reps: 14, workoutId: 'w2', start: '2026-02-01T10:00:00Z'),
      ]);

      final records = (await local.getRecord('user-1', ex))!;
      expect(records['mostReps'], {'reps': 14, 'workoutId': 'w2', 'at': '2026-02-01T10:00:00Z'});
      expect(records['totalReps'], 24);
    });

    test('assisted body weight treats less assistance as the record', () async {
      final ex = exercise(name: 'Assisted Dip', category: 'Assisted Body Weight');
      stub(ex.id, [
        row(weight: 20, reps: 8, workoutId: 'w1'),
        row(weight: 10, reps: 5, workoutId: 'w2'),
      ]);

      final records = (await local.getRecord('user-1', ex))!;
      expect((records['lightestAssistance'] as Map)['weight'], 10.0);
      expect((records['mostReps'] as Map)['reps'], 8);
    });

    test('duration', () async {
      final ex = exercise(name: 'Plank', category: 'Duration');
      stub(ex.id, [
        row(duration: 60, workoutId: 'w1'),
        row(duration: 90, workoutId: 'w2'),
      ]);

      final records = (await local.getRecord('user-1', ex))!;
      expect((records['longestDuration'] as Map)['duration'], 90.0);
      expect(records['totalDuration'], 150.0);
    });

    test('cardio: distance, duration and pace can come from different sets', () async {
      final ex = exercise(name: 'Run', category: 'Cardio');
      stub(ex.id, [
        // 5 km in 30 min: longest distance, but slower
        row(distance: 5, duration: 1800, workoutId: 'w1', start: '2026-01-01T10:00:00Z'),
        // 2 km in 600 s: best pace
        row(distance: 2, duration: 600, workoutId: 'w2', start: '2026-02-01T10:00:00Z'),
      ]);

      final records = (await local.getRecord('user-1', ex))!;
      expect((records['longestDistance'] as Map)['distance'], 5.0);
      expect((records['longestDuration'] as Map)['duration'], 1800.0);
      expect(records['bestPace'], {
        'pace': 300.0,
        'distance': 2.0,
        'duration': 600.0,
        'workoutId': 'w2',
        'at': '2026-02-01T10:00:00Z',
      });
      expect(records['totalDistance'], 7.0);
    });
  });

  group('degenerate inputs', () {
    test('never performed yields null', () async {
      final ex = exercise(name: 'Ghost', category: 'Barbell');
      stub(ex.id, []);
      expect(await local.getRecord('user-1', ex), isNull);
    });

    test('rows with only nulls yield null, not an empty records card', () async {
      final ex = exercise(name: 'Empty', category: 'Barbell');
      stub(ex.id, [row(weight: null, reps: null)]);
      expect(await local.getRecord('user-1', ex), isNull);
    });
  });
}
