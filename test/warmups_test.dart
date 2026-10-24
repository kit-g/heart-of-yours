// Warm-up sets (#158): the one offer on the workout sheet, the exercise menu's
// row, the ramp in Settings › Features, and the app without any of it — at a
// phone's width and an iPad's.
import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  // the app's own fonts, as the screens are laid out for them: the test font
  // is wider and overflows the app bars at phone width (pause_workout_test)
  setUpAll(() async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late HeartRouter router;

  final squat = Exercise(name: 'Squat', category: .barbell, target: .legs);

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    router = HeartRouter();
    stubStartup(db, api);
    SharedPreferences.setMockInitialValues({
      ...pastOnboarding(),
      'weightUnit': 'metric',
      'distanceUnit': 'metric',
    });
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.addSet(any, any)).thenAnswer((_) async {});
    when(db.removeSet(any)).thenAnswer((_) async {});
    when(db.storeMeasurements(any)).thenAnswer((_) async {});
    when(
      db.setExerciseUnit(exerciseName: anyNamed('exerciseName'), userId: anyNamed('userId'), unit: anyNamed('unit')),
    ).thenAnswer((_) async {});
    when(api.saveUnitPreference(any, any)).thenAnswer((_) async {});
  });

  Future<BuildContext> pumpApp(WidgetTester tester, {required double width}) async {
    rootBundle.clear();
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      router: router,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.pumpTimes();
    return tester.element(find.byType(MaterialApp));
  }

  /// A squat whose first set holds [weight] kilograms, as the active workout.
  Future<BuildContext> startSquat(WidgetTester tester, {required double width, double? weight = 100}) async {
    final template = Workout(name: 'Legs')..add(squat);
    template.first
      ..first.setMeasurements(weight: weight, reps: 5)
      ..add(ExerciseSet(squat, weight: weight, reps: 5));
    final context = await pumpApp(tester, width: width);
    await Workouts.of(context).startWorkout(source: .template, template: template);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    return context;
  }

  WorkoutExercise sheetSquat(BuildContext context) => Workouts.of(context).activeWorkout!.first;

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(squat.id));
    await tester.pumpTimes();
  }

  for (final width in [390.0, 1194.0]) {
    group('at ${width.round()}pt', () {
      testWidgets('the offer: a yes turns it on and adds the ramp before the first set', (tester) async {
        final context = await startSquat(tester, width: width);
        final prefs = Preferences.of(context);

        final offer = find.byKey(WorkoutDetailKeys.warmupsOffer);
        expect(offer, findsOneWidget);
        expect(find.textContaining('40 kg × 5, 60 kg × 3, 80 kg × 1'), findsOneWidget);
        // prose, so a measure rather than the pane's width
        final card = find.descendant(of: offer, matching: find.byType(Container)).first;
        expect(tester.getSize(card).width, lessThanOrEqualTo(readableWidth));
        expect(prefs.featureAnswer(.warmups), FeatureAnswer.pending, reason: 'showing it spends it');

        await tester.tapByKey(WorkoutDetailKeys.warmupsAccept);
        await tester.pumpTimes();

        expect(prefs.isOn(.warmups), isTrue);
        final sets = sheetSquat(context).toList();
        expect(sets.map((set) => (set.setType, set.weight, set.reps)), [
          (SetType.warmup, 40.0, 5),
          (SetType.warmup, 60.0, 3),
          (SetType.warmup, 80.0, 1),
          (SetType.normal, 100.0, 5),
          (SetType.normal, 100.0, 5),
        ]);
        expect(offer, findsNothing);
        // every row shows its own set, the moved ones included
        for (final set in sets) {
          final row = find.byKey(ValueKey<String>('_ExerciseSetItem.${set.id}'));
          final fields = tester.widgetList<TextField>(find.descendant(of: row, matching: find.byType(TextField)));
          expect(fields.map((field) => field.controller!.text), [
            Preferences.of(context).weight(set.weight!),
            '${set.reps}',
          ]);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('a no: one notice, then the app as it was', (tester) async {
        final context = await startSquat(tester, width: width);
        await tester.tapByKey(WorkoutDetailKeys.warmupsDecline);
        await tester.pumpTimes();

        expect(find.byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
        expect(sheetSquat(context).length, 2, reason: 'nothing added');

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpTimes();
        expect(find.byKey(AppKeys.featureDeclinedNotice), findsNothing);
        expect(find.byKey(WorkoutDetailKeys.warmupsOffer), findsNothing);

        await openMenu(tester);
        expect(find.byKey(WorkoutDetailKeys.addWarmupsFor(squat.id)), findsNothing);
      });

      testWidgets('no offer without a weight to warm up to', (tester) async {
        await startSquat(tester, width: width, weight: null);
        expect(find.byKey(WorkoutDetailKeys.warmupsOffer), findsNothing);
      });

      testWidgets('on, the menu adds them once; off, the row is gone and the sets stay', (tester) async {
        final context = await startSquat(tester, width: width);
        final prefs = Preferences.of(context)..setFeature(.warmups, on: true);
        await tester.pumpTimes();
        expect(find.byKey(WorkoutDetailKeys.warmupsOffer), findsNothing, reason: 'the switch is the answer');

        await openMenu(tester);
        await tester.tapByKey(WorkoutDetailKeys.addWarmupsFor(squat.id));
        await tester.pumpTimes();
        expect(sheetSquat(context).where((set) => set.setType == .warmup), hasLength(3));

        await openMenu(tester);
        expect(find.byKey(WorkoutDetailKeys.addWarmupsFor(squat.id)), findsNothing, reason: 'warm-ups are there');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpTimes();

        prefs.setFeature(.warmups, on: false);
        await tester.pumpTimes();
        expect(sheetSquat(context).where((set) => set.setType == .warmup), hasLength(3), reason: 'off never deletes');
        expect(tester.takeException(), isNull);
      });

      testWidgets("the exercise's own unit rounds to 5 lb", (tester) async {
        final context = await startSquat(tester, width: width);
        await Exercises.of(context).setUnit(squat, .imperial);
        Preferences.of(context).setFeature(.warmups, on: true);
        await tester.pumpTimes();

        await openMenu(tester);
        await tester.tapByKey(WorkoutDetailKeys.addWarmupsFor(squat.id));
        await tester.pumpTimes();

        // 100 kg is 220.5 lb: 88.2, 132.3, 176.4
        final warmups = sheetSquat(context).where((set) => set.setType == .warmup);
        expect(warmups.map((set) => set.weight!.asPounds.round()), [90, 130, 175]);
      });

      testWidgets('Settings › Features: the ramp unfolds while on, and changes live', (tester) async {
        final context = await pumpApp(tester, width: width);
        final prefs = Preferences.of(context);
        router.config.go('/profile/settings/features?feature=warmups');
        await tester.pumpTimes(25);
        expect(find.byType(FeaturesPage), findsOneWidget);
        expect(find.text('40% × 5'), findsNothing, reason: 'off, never built');

        prefs.setFeature(.warmups, on: true);
        await tester.pumpTimes();
        expect(find.text('40% × 5'), findsOneWidget);
        expect(find.text('80% × 1'), findsOneWidget);
        expect(find.byKey(const ValueKey('warmup-scheme-reset')), findsNothing, reason: 'it is the default');

        await tester.ensureVisible(find.text('80% × 1'));
        await tester.pumpTimes();
        await tester.tap(find.text('80% × 1'));
        await tester.pumpTimes();
        await tester.enterText(find.byKey(const ValueKey('warmup-step-percent')), '85');
        await tester.enterText(find.byKey(const ValueKey('warmup-step-reps')), '2');
        await tester.tapByKey(const ValueKey('warmup-step-save'));
        await tester.pumpTimes();

        expect(prefs.warmupScheme.last, (percent: 85, reps: 2));
        expect(find.text('85% × 2'), findsOneWidget);

        await tester.tap(find.byTooltip('Remove 40% × 5'));
        await tester.pumpTimes();
        expect(prefs.warmupScheme, [(percent: 60, reps: 3), (percent: 85, reps: 2)]);

        await tester.tapByKey(const ValueKey('warmup-scheme-reset'));
        await tester.pumpTimes();
        expect(prefs.warmupScheme, defaultWarmupScheme);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a rung the ramp cannot hold keeps the dialog open', (tester) async {
        final context = await pumpApp(tester, width: width);
        Preferences.of(context).setFeature(.warmups, on: true);
        router.config.go('/profile/settings/features?feature=warmups');
        await tester.pumpTimes(25);

        await tester.tapByKey(const ValueKey('warmup-step-add'));
        await tester.pumpTimes();
        expect(
          tester.widget<TextField>(find.byKey(const ValueKey('warmup-step-percent'))).controller!.text,
          '90',
          reason: 'halfway from 80 to the working weight',
        );
        await tester.enterText(find.byKey(const ValueKey('warmup-step-reps')), '0');
        await tester.tapByKey(const ValueKey('warmup-step-save'));
        await tester.pumpTimes();
        expect(find.byType(Dialog), findsOneWidget);
        expect(Preferences.of(context).warmupScheme, defaultWarmupScheme);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
