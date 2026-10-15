// The new-exercise dialog's movement pattern (#343): offered from the
// library's own keys under the filters' labels, never required, and editable
// later from the exercise. Pumped bare rather than through the app harness:
// the dialog needs only [Exercises] and the localizations, and the harness
// never reads the mirror (a widget test stops at startup's first await).
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/exercises/new_exercise_dialog.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

void main() {
  late MockExerciseService local;
  late Exercises exercises;

  Exercise ex(String id, String name, {List<String> groups = const [], bool own = false}) {
    return Exercise.fromJson({
      'id': id,
      'name': name,
      'category': 'Machine',
      'target': 'Chest',
      'own': own,
      if (groups.isNotEmpty) 'movement': {'groups': groups},
    });
  }

  final fly = ex('fly', 'Pec Deck', groups: ['chest_fly']);
  final press = ex('press', 'Chest Press', groups: ['horizontal_press']);

  setUp(() async {
    local = MockExerciseService();
    when(local.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(local.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: local,
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
      onError: (_, {stacktrace}) {},
    );
  });

  Future<void> pumpDialog(WidgetTester tester, List<Exercise> mirror, {Exercise? editable}) async {
    when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, mirror));
    await tester.runAsync(exercises.init);
    await tester.pumpWidget(
      ChangeNotifierProvider<Exercises>.value(
        value: exercises,
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showNewExerciseDialog(context, editable: editable),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder patternValue(String text) =>
      find.descendant(of: find.byKey(AppKeys.newExercisePattern), matching: find.text(text));

  Future<void> pick(WidgetTester tester, String? pattern) async {
    await tester.ensureVisible(find.byKey(AppKeys.newExercisePattern));
    await tester.tap(find.byKey(AppKeys.newExercisePattern));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.newExercisePatternOption(pattern)));
    await tester.pumpAndSettle();
  }

  PrimaryButton save(WidgetTester tester) => tester.widget(find.widgetWithText(PrimaryButton, 'Save'));

  testWidgets("the menu is None and the library's patterns, under the filters' labels", (tester) async {
    await pumpDialog(tester, [fly, press]);
    expect(patternValue('None'), findsOneWidget);

    await tester.ensureVisible(find.byKey(AppKeys.newExercisePattern));
    await tester.tap(find.byKey(AppKeys.newExercisePattern));
    await tester.pumpAndSettle();

    for (final (key, label) in [(null, 'None'), ('chest_fly', 'Chest Fly'), ('horizontal_press', 'Horizontal Press')]) {
      expect(
        find.descendant(of: find.byKey(AppKeys.newExercisePatternOption(key)), matching: find.text(label)),
        findsOneWidget,
      );
    }
  });

  testWidgets('a new exercise saves without a pattern, and with the one picked', (tester) async {
    await pumpDialog(tester, [fly]);
    await tester.enterText(find.byType(TextField), 'Cable Fly');
    await tester.tap(find.widgetWithText(InputChip, 'Chest'));
    await tester.ensureVisible(find.widgetWithText(InputChip, 'Machine'));
    await tester.tap(find.widgetWithText(InputChip, 'Machine'));
    await tester.pumpAndSettle();
    // never required
    expect(save(tester).onPressed, isNotNull);

    await pick(tester, 'chest_fly');
    expect(patternValue('Chest Fly'), findsOneWidget);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();

    final made = exercises.firstWhere((each) => each.name == 'Cable Fly');
    expect(made.movement.groups, ['chest_fly']);
  });

  testWidgets("an own exercise's pattern alone is an edit, and None clears it", (tester) async {
    final mine = ex('mine', 'Cable Fly', groups: ['chest_fly'], own: true);
    await pumpDialog(tester, [fly, press, mine], editable: mine);
    expect(patternValue('Chest Fly'), findsOneWidget);
    expect(save(tester).onPressed, isNull, reason: 'nothing changed yet');

    await pick(tester, null);
    expect(save(tester).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();

    expect(exercises.lookup('mine')?.movement.isEmpty, isTrue);
  });
}
