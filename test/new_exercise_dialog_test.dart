// Coverage for lib/presentation/widgets/exercises/new_exercise_dialog.dart:
// creating a custom exercise (name, target, category) through its real entry
// point — the Exercises tab's options menu — and the save button's own
// enablement (name/target/category all required).
import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/exercises/new_exercise_dialog.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_api/heart_api.dart' show ExerciseNameTaken;
import 'package:heart_models/heart_models.dart';
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

  Finder nameField() => find.byKey(AppKeys.newExerciseName);

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

  testWidgets('a name keeps any script and its punctuation (#527)', (tester) async {
    await pumpToNewExerciseDialog(tester);

    for (final name in ['Жим лёжа', 'Press francés', "Farmer's walk", 'T-bar row (pause)']) {
      await tester.enterTextAndWait(nameField(), name);
      expect(tester.widget<TextField>(nameField()).controller?.text, name);
    }

    await tester.enterTextAndWait(nameField(), 'Тяга\tблока');
    expect(
      tester.widget<TextField>(nameField()).controller?.text,
      'Тягаблока',
      reason: 'a control character stays out',
    );
  });
  testWidgets('a save in flight holds the dialog open, and its end closes only the dialog (#607)', (tester) async {
    await pumpToNewExerciseDialog(tester);

    // the save hangs on the store until the test lets it through
    final store = Completer<void>();
    when(db.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) => store.future);

    await tester.enterTextAndWait(nameField(), 'Slow Save');
    await tester.tap(find.text('Legs'));
    await tester.pumpTimes();
    await tester.ensureVisible(find.text('Barbell'));
    await tester.pumpTimes();
    await tester.tap(find.text('Barbell'));
    await tester.pumpTimes();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpTimes();

    // Back, the close button and a tap outside all ask, and mid-save the answer is no
    await tester.binding.handlePopRoute();
    await tester.pumpTimes();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpTimes();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpTimes();
    expect(find.text('Create new exercise'), findsOneWidget);

    store.complete();
    await tester.pumpTimes();

    expect(find.text('Create new exercise'), findsNothing);
    // the page beneath is untouched, and still answers
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Exercise options'));
    await tester.pumpTimes();
    expect(find.text('New exercise'), findsOneWidget);
  });

  group('editing an own exercise (#616)', () {
    final own = Exercise.fromJson({
      'id': '019e8b5d-c52d-729e-be9c-a5403b04fd1b',
      'name': 'Landmine Press',
      'category': 'Barbell',
      'target': 'Shoulders',
      'own': 1,
    });

    Future<BuildContext> pumpToEdit(WidgetTester tester, Exercise editable) async {
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: MockFirebaseAuth(signedIn: false),
        settle: false,
      );
      await tester.pumpTimes();
      // below the app's localizations and navigator, as a page's would be
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(showNewExerciseDialog(context, editable: editable));
      await tester.pumpTimes();
      return context;
    }

    Widget save(WidgetTester tester) => tester.widget(find.widgetWithText(PrimaryButton, 'Save'));

    testWidgets('offers the name prefilled, and a new one saves under the same id', (tester) async {
      final context = await pumpToEdit(tester, own);

      expect(tester.widget<TextField>(nameField()).controller?.text, 'Landmine Press');
      expect((save(tester) as PrimaryButton).onPressed, isNull, reason: 'nothing changed yet');

      await tester.enterTextAndWait(nameField(), '   ');
      expect((save(tester) as PrimaryButton).onPressed, isNull, reason: 'a blank name is no name');

      await tester.enterTextAndWait(nameField(), '  Landmine Press, half-kneeling ');
      expect((save(tester) as PrimaryButton).onPressed, isNotNull);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await tester.pumpTimes();

      expect(find.text('Create new exercise'), findsNothing);
      final renamed = Exercises.of(context).lookup(own.id);
      expect(renamed?.name, 'Landmine Press, half-kneeling');
      expect(renamed?.isMine, isTrue);
    });

    testWidgets('the target can change too', (tester) async {
      final context = await pumpToEdit(tester, own);

      await tester.tap(find.text('Chest'));
      await tester.pumpTimes();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await tester.pumpTimes();

      expect(Exercises.of(context).lookup(own.id)?.target, Target.chest);
    });

    testWidgets('a name another own exercise has is said in the field, and not saved', (tester) async {
      final context = await pumpToEdit(tester, own);
      await Exercises.of(context).makeExercise(
        Exercise(name: 'Push Press', category: .barbell, target: .chest, isMine: true),
      );

      await tester.enterTextAndWait(nameField(), 'push press');

      expect(find.text('You already have an exercise with this name'), findsOneWidget);
      expect((save(tester) as PrimaryButton).onPressed, isNull);
    });

    testWidgets('a name the server refuses keeps the dialog open, saying why', (tester) async {
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'u1', email: 'u1@test'),
          signedIn: true,
        ),
        settle: false,
      );
      await tester.pumpTimes();
      when(api.renameExercise(any)).thenThrow(const ExerciseNameTaken());
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(showNewExerciseDialog(context, editable: own));
      await tester.pumpTimes();

      await tester.enterTextAndWait(nameField(), 'Taken Elsewhere');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await tester.pumpTimes();

      expect(find.text('Create new exercise'), findsOneWidget);
      expect(find.text('You already have an exercise with this name'), findsOneWidget);
      verify(api.renameExercise(any)).called(1);
      verifyNever(api.editExercise(any));

      await tester.enterTextAndWait(nameField(), 'Taken Elsewhere 2');
      expect(find.text('You already have an exercise with this name'), findsNothing);
    });

    testWidgets('instructions alone are an edit, saved trimmed, and cleared to none (#621)', (tester) async {
      final context = await pumpToEdit(tester, own);
      Finder field() => find.byKey(AppKeys.newExerciseInstructions);

      await tester.ensureVisible(field());
      await tester.enterTextAndWait(field(), '  Knee on a pad, press up and across.  ');
      expect((save(tester) as PrimaryButton).onPressed, isNotNull);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await tester.pumpTimes();
      expect(Exercises.of(context).lookup(own.id)?.instructions, 'Knee on a pad, press up and across.');

      unawaited(showNewExerciseDialog(context, editable: own));
      await tester.pumpTimes();
      expect(tester.widget<TextField>(field()).controller?.text, 'Knee on a pad, press up and across.');
      await tester.ensureVisible(field());
      await tester.enterTextAndWait(field(), '   ');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await tester.pumpTimes();
      expect(Exercises.of(context).lookup(own.id)?.instructions, isNull);
      expect(Exercises.of(context).lookup(own.id)?.hasInfo, isFalse, reason: 'no About tab for nothing');
    });

    testWidgets("a library exercise's name is not a field", (tester) async {
      await pumpToEdit(tester, Exercise.fromJson({...own.toMap(), 'own': 0}));

      expect(find.descendant(of: find.byType(Card), matching: find.byType(TextField)), findsNothing);
      expect(find.text('Landmine Press'), findsOneWidget);
    });
  });
}
