// Coverage for lib/presentation/widgets/exercises/new_exercise_dialog.dart:
// creating a custom exercise (name, target, category) through its real entry
// point — the Exercises tab's options menu — and the save button's own
// enablement (name/target/category all required).
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);
    when(db.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
  });

  /// Drives a real launch to the dialog: the Exercises tab, its options
  /// button, and "New exercise" in the menu it opens.
  Future<void> pumpToNewExerciseDialog(WidgetTester tester) async {
    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(signedIn: false),
      settle: false,
    );
    await tester.pumpTimes();

    await tester.tapByKey(AppKeys.exercisesStack);
    await tester.pumpTimes();
    await tester.tap(find.byTooltip('Exercise options'));
    await tester.pumpTimes();
    await tester.tap(find.text('New exercise'));
    await tester.pumpTimes();

    expect(find.text('Create new exercise'), findsOneWidget);
  }

  Finder nameField() => find.descendant(of: find.byType(Card), matching: find.byType(TextField));

  testWidgets('save is disabled until a name, a target and a category are all set', (tester) async {
    await pumpToNewExerciseDialog(tester);

    Widget save() => tester.widget(find.widgetWithText(PrimaryButton, 'Save'));
    expect((save() as PrimaryButton).onPressed, isNull);

    await tester.enterTextAndWait(nameField(), 'Squat Variant');
    expect((save() as PrimaryButton).onPressed, isNull, reason: 'still missing a target and a category');

    await tester.tap(find.text('Chest'));
    await tester.pumpTimes();
    expect((save() as PrimaryButton).onPressed, isNull, reason: 'still missing a category');

    // ten category chips wrap past the test surface's fold
    await tester.ensureVisible(find.text('Barbell'));
    await tester.pumpTimes();
    await tester.tap(find.text('Barbell'));
    await tester.pumpTimes();
    expect((save() as PrimaryButton).onPressed, isNotNull);
  });

  testWidgets('saving stores the new exercise locally and closes the dialog', (tester) async {
    await pumpToNewExerciseDialog(tester);

    await tester.enterTextAndWait(nameField(), 'Squat Variant');
    await tester.tap(find.text('Legs'));
    await tester.pumpTimes();
    // ten category chips wrap past the test surface's fold
    await tester.ensureVisible(find.text('Barbell'));
    await tester.pumpTimes();
    await tester.tap(find.text('Barbell'));
    await tester.pumpTimes();

    final context = tester.element(find.byType(MaterialApp));
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpTimes();

    expect(find.text('Create new exercise'), findsNothing);
    expect(
      Exercises.of(context).any((e) => e.name == 'Squat Variant' && e.target == .legs && e.category == .barbell),
      isTrue,
    );
    verify(db.storeExercises(any, userId: anyNamed('userId'))).called(greaterThanOrEqualTo(1));
  });

  testWidgets('the close button dismisses without creating anything', (tester) async {
    await pumpToNewExerciseDialog(tester);

    await tester.enterTextAndWait(nameField(), 'Abandoned Exercise');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpTimes();

    expect(find.text('Create new exercise'), findsNothing);
    final context = tester.element(find.byType(MaterialApp));
    expect(Exercises.of(context).any((e) => e.name == 'Abandoned Exercise'), isFalse);
  });
}
