// A custom exercise made from the picker that adds exercises to a template or
// a workout, without leaving either (#529): through the picker's New exercise
// button, and through the offer a search that found nothing makes. The new
// exercise comes back ticked, the way picking one does, and Add brings it in.
//
// Drives the real app: the template editor and the active workout are reached
// through the Workout tab, as in `templates_test.dart` and
// `workout_start_test.dart`.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart' show ExerciseItem;
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/search_field.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart' show WorkoutDetailKeys;
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  const userId = 'u1';
  const name = 'Muffin Hack Squat';
  // the library is in, so a search has something to find nothing in
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

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
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));

    when(db.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(api.makeExercise(any)).thenAnswer((i) async => i.positionalArguments.single as Exercise);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.startExercise(any, any)).thenAnswer((_) async {});

    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    when(db.getTemplates(any)).thenAnswer((_) async => <Template>[]);
    when(api.getTemplates()).thenAnswer((_) async => null);
    when(db.getTemplateFolders(userId)).thenAnswer((_) async => <TemplateFolder>[]);
    when(api.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => <TemplateFolder>[]);
    when(db.storeTemplates(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(db.startTemplate(order: anyNamed('order'), userId: anyNamed('userId'))).thenAnswer(
      (i) async => Template.empty(id: 'draft-1', order: i.namedArguments[#order] as int? ?? 0),
    );
  });

  /// The library read in, which is what lets a search come back empty
  /// rather than still loading. Called directly for the reason
  /// `openWorkoutTab` in templates_test.dart gives: the startup chain never
  /// resolves under a widget test's clock.
  Future<void> readLibrary(WidgetTester tester) async {
    await Exercises.of(tester.element(find.byType(MaterialApp))).init();
    await tester.pumpTimes();
  }

  Future<void> launch(WidgetTester tester) async {
    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: userId, email: '$userId@test'),
        signedIn: true,
      ),
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    await readLibrary(tester);
  }

  /// A brand-new template's editor, open on its picker.
  Future<void> openTemplatePicker(WidgetTester tester) async {
    await launch(tester);
    // directly, as the library above
    final templates = Templates.of(tester.element(find.byType(MaterialApp)));
    await templates.init();
    templates.notifyListeners();
    await tester.pumpTimes();

    await tester.tap(find.widgetWithText(PrimaryButton, 'Template'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateEditor), findsOneWidget);

    await tester.tapByKey(WorkoutDetailKeys.addExercises);
    await tester.pumpTimes();
  }

  /// An empty workout, open on its picker.
  Future<void> openWorkoutPicker(WidgetTester tester) async {
    await launch(tester);
    await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
    await tester.pumpTimes();

    await tester.tapByKey(WorkoutDetailKeys.addExercises);
    await tester.pumpTimes();
  }

  Finder dialogName() {
    return find.descendant(
      of: find.ancestor(of: find.text('Create new exercise'), matching: find.byType(Card)),
      matching: find.byType(TextField),
    );
  }

  /// Fills in what the dialog needs past a name and saves.
  Future<void> finishDialog(WidgetTester tester) async {
    await tester.tap(find.text('Legs'));
    await tester.pumpTimes();
    // ten category chips wrap past the test surface's fold
    await tester.ensureVisible(find.text('Machine'));
    await tester.pumpTimes();
    await tester.tap(find.text('Machine'));
    await tester.pumpTimes();
    // the dialog's, over the template editor's own
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save').last);
    await tester.pumpTimes();
    expect(find.text('Create new exercise'), findsNothing);
  }

  /// Creates [name] through the picker's own button.
  Future<void> createFromButton(WidgetTester tester) async {
    await tester.tap(find.byTooltip('New exercise'));
    await tester.pumpTimes();
    expect(find.text('Create new exercise'), findsOneWidget);
    expect(tester.widget<TextField>(dialogName()).controller?.text, isEmpty);

    await tester.enterTextAndWait(dialogName(), name);
    await finishDialog(tester);
  }

  /// Creates [name] through the offer a search that found nothing makes.
  Future<void> createFromSearch(WidgetTester tester) async {
    await tester.enterTextAndWait(
      find.descendant(of: find.byType(SearchField), matching: find.byType(TextField)),
      name,
    );
    expect(find.text('Create “$name”'), findsOneWidget);

    await tester.tapByKey(AppKeys.pickerCreateExercise);
    await tester.pumpTimes();
    expect(find.text('Create new exercise'), findsOneWidget);
    expect(tester.widget<TextField>(dialogName()).controller?.text, name, reason: 'the search fills in the name');

    await finishDialog(tester);
  }

  /// The new exercise is ticked, in view, and stored; Add brings it in.
  Future<void> addPicked(WidgetTester tester) async {
    final context = tester.element(find.byType(MaterialApp));
    final made = Exercises.of(context).firstWhere((each) => each.name == name);
    expect(made.isMine, isTrue);
    expect(Exercises.of(context).hasSelected(made), isTrue);
    expect(find.byKey(AppKeys.pickerCreateExercise), findsNothing, reason: 'the search finds it now');
    verify(db.storeExercises(any, userId: anyNamed('userId'))).called(greaterThanOrEqualTo(1));

    await tester.tapByKey(WorkoutDetailKeys.addExerciseButton);
    await tester.pumpTimes();
  }

  group('from the template editor', () {
    Future<void> expectInTemplate(WidgetTester tester) async {
      final editable = Templates.of(tester.element(find.byType(MaterialApp))).editable;
      expect(editable?.map((each) => each.exercise.name), [name]);
    }

    testWidgets('the New exercise button makes one and the template takes it', (tester) async {
      await openTemplatePicker(tester);
      await createFromButton(tester);
      await addPicked(tester);
      await expectInTemplate(tester);
    });

    testWidgets('a search that finds nothing makes one by that name', (tester) async {
      await openTemplatePicker(tester);
      await createFromSearch(tester);
      await addPicked(tester);
      await expectInTemplate(tester);
    });
  });

  group('from an active workout', () {
    void expectInWorkout(WidgetTester tester) {
      final workout = Workouts.of(tester.element(find.byType(MaterialApp))).activeWorkout;
      expect(workout?.map((each) => each.exercise.name), [name]);
    }

    testWidgets('the New exercise button makes one and the workout takes it', (tester) async {
      await openWorkoutPicker(tester);
      await createFromButton(tester);
      await addPicked(tester);
      expectInWorkout(tester);
    });

    testWidgets('a search that finds nothing makes one by that name', (tester) async {
      await openWorkoutPicker(tester);
      await createFromSearch(tester);
      await addPicked(tester);
      expectInWorkout(tester);
    });

    testWidgets('closing the dialog leaves nothing made and nothing ticked', (tester) async {
      await openWorkoutPicker(tester);
      await tester.tap(find.byTooltip('New exercise'));
      await tester.pumpTimes();
      await tester.enterTextAndWait(dialogName(), name);
      // the dialog's Close, not the picker's beneath it
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpTimes();

      final exercises = Exercises.of(tester.element(find.byType(MaterialApp)));
      expect(find.text('Create new exercise'), findsNothing);
      expect(exercises.any((each) => each.name == name), isFalse);
      expect(exercises.selected, isEmpty);
    });
  });

  group('from the library', () {
    testWidgets('a search that finds nothing makes one by that name', (tester) async {
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
      await readLibrary(tester);

      await createFromSearch(tester);

      final exercises = Exercises.of(tester.element(find.byType(MaterialApp)));
      expect(exercises.any((each) => each.name == name && each.isMine), isTrue);
      expect(
        find.descendant(of: find.byType(ExerciseItem), matching: find.text(name)),
        findsOneWidget,
        reason: 'the search that found nothing finds it now',
      );
      expect(find.byKey(AppKeys.pickerCreateExercise), findsNothing);
    });
  });
}
