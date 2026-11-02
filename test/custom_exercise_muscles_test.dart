// A custom exercise's muscles, tagged on the body atlas in its dialog (#176):
// a tap tags the whole muscle in the role the switch shows, a second tap
// untags it, and the tagging is the library's own shape, so the muscle map
// counts the exercise's sets instead of leaving them out. Pumped bare, like the
// pattern's test beside it.
import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/muscle_volume.dart';
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

  // hit-testing the painted figure needs its SVG off the asset bundle, which
  // fake time never loads; the callback is what a hit resolves to
  Future<void> tapMuscle(WidgetTester tester, String id) async {
    await tester.ensureVisible(find.byKey(AppKeys.musclePickerFigures));
    final atlas = tester.widget<BodyAtlasView<MuscleInfo>>(find.byType(BodyAtlasView<MuscleInfo>).first);
    atlas.onTapElement!(MuscleCatalog.byIdOrThrow(id));
    await tester.pumpAndSettle();
  }

  Future<void> role(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.byKey(AppKeys.musclePickerRole));
    await tester.tap(find.descendant(of: find.byKey(AppKeys.musclePickerRole), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  PrimaryButton save(WidgetTester tester) => tester.widget(find.widgetWithText(PrimaryButton, 'Save'));

  Exercise mine({Map<String, dynamic>? muscles}) {
    return Exercise.fromJson({
      'id': 'mine',
      'name': 'Muffin Hold',
      'category': 'Dumbbell',
      'target': 'Other',
      'own': true,
      'muscles': ?muscles,
    });
  }

  testWidgets('a new exercise saves the muscles tagged, both sides and every segment of each', (tester) async {
    await pumpDialog(tester, []);
    await tester.enterText(find.byType(TextField), 'Muffin Press');
    await tester.tap(find.widgetWithText(InputChip, 'Chest'));
    await tester.ensureVisible(find.widgetWithText(InputChip, 'Machine'));
    await tester.tap(find.widgetWithText(InputChip, 'Machine'));
    await tester.pumpAndSettle();
    // never required
    expect(save(tester).onPressed, isNotNull);

    await tapMuscle(tester, 'pectoralis_major_l');
    await role(tester, 'Secondary');
    await tapMuscle(tester, 'triceps_brachii_caput_laterale_r');
    expect(find.text('Primary: Chest'), findsOneWidget);
    expect(find.text('Secondary: Arms'), findsOneWidget);

    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();

    final made = exercises.firstWhere((each) => each.name == 'Muffin Press');
    expect(made.muscles.primary.ids, containsAll(['pectoralis_major_l', 'pectoralis_major_r']));
    expect(
      made.muscles.secondary?.ids,
      containsAll(['triceps_brachii_caput_laterale_l', 'triceps_brachii_caput_laterale_r']),
    );
  });

  testWidgets('a second tap in the same role untags; in the other role it moves the muscle', (tester) async {
    await pumpDialog(tester, []);

    await tapMuscle(tester, 'rectus_abdominis_2_l');
    expect(find.text('Primary: Core'), findsOneWidget);
    await tapMuscle(tester, 'rectus_abdominis_3_r');
    expect(find.textContaining('Primary:'), findsNothing);

    await tapMuscle(tester, 'rectus_abdominis_1');
    await role(tester, 'Secondary');
    await tapMuscle(tester, 'rectus_abdominis_1');
    expect(find.textContaining('Primary:'), findsNothing);
    expect(find.text('Secondary: Core'), findsOneWidget);
  });

  testWidgets('tagging alone is an edit, and the muscle map then counts the sets it used to leave out', (tester) async {
    final untagged = mine();
    final row = (start: DateTime(2026, 10, 18), muscles: untagged.muscles, target: untagged.target, sets: 3);
    final before = muscleVolume([row]);
    expect(before.sets, isEmpty);
    expect(before.unmapped, 3);

    await pumpDialog(tester, [untagged], editable: untagged);
    expect(save(tester).onPressed, isNull, reason: 'nothing changed yet');

    await tapMuscle(tester, 'gluteus_maximus_l');
    expect(save(tester).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();

    final tagged = exercises.lookup('mine')!;
    final after = muscleVolume([(start: row.start, muscles: tagged.muscles, target: tagged.target, sets: 3)]);
    expect(after.sets, {MuscleGroup.glutes: 3.0});
    expect(after.unmapped, 0);
  });

  testWidgets('an edit that leaves the muscles alone keeps their tagging exactly', (tester) async {
    final tagged = mine(
      muscles: {
        'primary': {
          'groups': ['legs'],
        },
      },
    );
    await pumpDialog(tester, [tagged], editable: tagged);

    await tester.ensureVisible(find.widgetWithText(InputChip, 'Barbell'));
    await tester.tap(find.widgetWithText(InputChip, 'Barbell'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();

    expect(exercises.lookup('mine')?.muscles.toMap(), tagged.muscles.toMap());
  });
}
