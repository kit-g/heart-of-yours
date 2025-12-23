import 'package:heart_models/heart_models.dart';
import 'package:test/test.dart';

void main() {
  group('ChartPreference', () {
    test('ChartPreference.fromRow works with exerciseWeight', () {
      final row = {
        'id': '1',
        'type': 'exerciseWeight',
        'data': '{"exerciseName": "Bench Press"}'
      };
      final pref = ChartPreference.fromRow(row);

      expect(pref.id, '1');
      expect(pref.type, ChartPreferenceType.exerciseWeight);
      expect(pref.exerciseName, 'Bench Press');
    });

    test('ChartPreference.fromRow works with null data', () {
      final row = {
        'id': '2',
        'type': 'exerciseReps',
        'data': null
      };
      final pref = ChartPreference.fromRow(row);

      expect(pref.id, '2');
      expect(pref.type, ChartPreferenceType.exerciseReps);
      expect(pref.data, isNull);
    });

    test('ChartPreference.exerciseWeight factory works', () {
      final pref = ChartPreference.exerciseWeight('Squat');

      expect(pref.id, isNull);
      expect(pref.type, ChartPreferenceType.exerciseWeight);
      expect(pref.exerciseName, 'Squat');
    });

    test('toRow works', () {
      final pref = ChartPreference.exerciseWeight('Deadlift');
      final row = pref.toRow();

      expect(row['id'], isNull);
      expect(row['type'], 'exerciseWeight');
      expect(row['data'], '{"exerciseName":"Deadlift"}');
    });

    test('copyWith works', () {
      final pref = ChartPreference.exerciseWeight('Bench Press');
      final updated = pref.copyWith(id: 'new-id');

      expect(updated.id, 'new-id');
      expect(updated.type, pref.type);
      expect(updated.exerciseName, pref.exerciseName);
    });
  });

  group('ChartPreferenceType', () {
    test('fromString works', () {
      expect(ChartPreferenceType.fromString('exerciseWeight'), ChartPreferenceType.exerciseWeight);
      expect(ChartPreferenceType.fromString('exerciseReps'), ChartPreferenceType.exerciseReps);
    });

    test('fromString throws on invalid value', () {
      expect(() => ChartPreferenceType.fromString('invalid'), throwsArgumentError);
    });
  });
}
