// showMovementFilterSheet / _MovementFilterSheet
// (lib/presentation/widgets/exercises/movement_filter_sheet.dart) — the bottom
// sheet that filters the exercise picker (and the library's own filter
// control) by movement pattern, skill ceiling and stability, rather than by
// equipment or body part.
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart' hide Page;

import 'support/exercise_detail_test_helpers.dart';

Future<L> _pump(WidgetTester tester, Exercises exercises) async {
  L? l;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Builder(
        builder: (context) {
          l = L.of(context);
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showMovementFilterSheet(context, exercises),
                child: const Text('open'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return l!;
}

void main() {
  late Exercises exercises;

  setUp(() async {
    final state = await buildExerciseDetailState();
    exercises = state.exercises;
    // a pattern chip only renders for a pattern the library actually uses
    await exercises.makeExercise(
      Exercise(
        name: 'Bench Press',
        category: .barbell,
        target: .chest,
        movement: Movement.fromJson({
          'groups': ['horizontal_press'],
        }),
      ),
    );
  });

  testWidgets('opens over the picker with a section per movement dimension', (tester) async {
    final l = await _pump(tester, exercises);

    expect(find.text(l.stability), findsOneWidget);
    expect(find.text(l.skillAtMost), findsOneWidget);
    expect(find.text(l.pattern), findsOneWidget);
    expect(find.text(l.patternHorizontalPress), findsOneWidget);
    // nothing selected yet: no "clear filters" affordance
    expect(find.text(l.clearFilters), findsNothing);
  });

  testWidgets('toggling a stability chip updates the live exercise filters', (tester) async {
    final l = await _pump(tester, exercises);

    await tester.tap(find.text(l.stabilityFree));
    await tester.pump();

    expect(exercises.movementFilters, contains(const StabilityFilter(.free)));

    await tester.tap(find.text(l.stabilityFree));
    await tester.pump();

    expect(exercises.movementFilters, isNot(contains(const StabilityFilter(.free))));
  });

  testWidgets('a skill ceiling and a pattern chip both apply, and Clear filters removes both', (tester) async {
    final l = await _pump(tester, exercises);

    await tester.tap(find.text(l.skillLow));
    await tester.pump();
    await tester.tap(find.text(l.patternHorizontalPress));
    await tester.pump();

    expect(
      exercises.movementFilters,
      containsAll([const SkillCeiling(.low), const PatternFilter('horizontal_press')]),
    );
    expect(find.text(l.clearFilters), findsOneWidget);

    await tester.tap(find.text(l.clearFilters));
    await tester.pump();

    expect(exercises.movementFilters, isEmpty);
    expect(find.text(l.clearFilters), findsNothing);
  });

  testWidgets('`high` skill is never offered — it would filter nothing', (tester) async {
    final l = await _pump(tester, exercises);

    expect(find.text(l.skillHigh), findsNothing);
    expect(find.text(l.skillLow), findsOneWidget);
    expect(find.text(l.skillModerate), findsOneWidget);
  });
}
