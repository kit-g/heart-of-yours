// The records a workout set, placed on the sets that set them (#F20).
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  Workout session() {
    final light = ExerciseSet(bench, weight: 80, reps: 8)..isCompleted = true;
    final heavy = ExerciseSet(bench, weight: 105, reps: 3)..isCompleted = true;
    return Workout.fromExercises([WorkoutExercise(starter: light)..add(heavy)]);
  }

  test('a beaten record lands on the set whose values it holds', () {
    final workout = session();
    final heavy = workout.first.last;
    final marks = recordMarks(workout, [
      (
        exercise: bench,
        kind: RecordKind.maxWeight,
        record: {
          'weight': 105.0,
          'reps': 3,
          'workoutId': workout.id,
          'previous': {'weight': 100.0, 'reps': 3},
        },
      ),
    ]);

    expect(marks, {
      heavy.id: [RecordKind.maxWeight],
    });
  });

  test("an exercise's first time marks nothing: every record would fall at once", () {
    final workout = session();
    final marks = recordMarks(workout, [
      (exercise: bench, kind: RecordKind.maxWeight, record: {'weight': 105.0, 'reps': 3, 'workoutId': workout.id}),
    ]);

    expect(marks, isEmpty);
  });

  test('several records on one set stay on that one set', () {
    final workout = session();
    final heavy = workout.first.last;
    final beaten = {'previous': <String, Object>{}};
    final marks = recordMarks(workout, [
      (exercise: bench, kind: RecordKind.maxWeight, record: {'weight': 105.0, 'reps': 3, ...beaten}),
      (exercise: bench, kind: RecordKind.oneRepMax, record: {'value': 111.0, 'weight': 105.0, 'reps': 3, ...beaten}),
    ]);

    expect(marks, {
      heavy.id: [RecordKind.maxWeight, RecordKind.oneRepMax],
    });
  });

  Future<void> pumpScoped(WidgetTester tester, Widget child, {RecordMarks marks = const {}, String? first}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: RecordMarksScope(marks: marks, firstSetId: first, child: child),
        ),
      ),
    );
  }

  testWidgets('a set\'s records are short pills, each saying its full name', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScoped(
      tester,
      const RecordPills(kinds: [RecordKind.oneRepMax, RecordKind.bestVolume, RecordKind.maxWeight]),
    );

    expect(find.text('1RM'), findsOneWidget);
    expect(find.text('VOL.'), findsOneWidget);
    expect(find.text('WEIGHT'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Record: ')), findsNWidgets(3));
    semantics.dispose();
  });

  testWidgets('the count says how many records the page holds, and is absent with none', (tester) async {
    await pumpScoped(
      tester,
      const RecordCountRow(),
      marks: {
        's1': [RecordKind.maxWeight, RecordKind.oneRepMax],
        's2': [RecordKind.bestVolume],
      },
      first: 's1',
    );
    expect(find.text('3 PRs'), findsOneWidget);

    await pumpScoped(tester, const RecordCountRow());
    expect(find.textContaining('PR'), findsNothing);
  });
}
