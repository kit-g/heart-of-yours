import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/muscle_figures.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// A template's plan on the muscle map (#263): one line, the figures behind
/// it, and nothing at all when the user does not have it.
void main() {
  late Exercises exercises;
  late Preferences preferences;

  final bench = Exercise(
    name: 'Bench Press (Barbell)',
    category: .barbell,
    target: .chest,
    tags: MuscleTagging.fromJson(jsonDecode('{"primary": {"groups": ["chest"]}}')),
  );
  final squat = Exercise(
    name: 'Squat (Barbell)',
    category: .barbell,
    target: .legs,
    tags: MuscleTagging.fromJson(jsonDecode('{"primary": {"groups": ["legs"]}}')),
  );
  // the user's own, untagged, and for the whole body: nothing places it
  final carry = Exercise(name: 'Muffin Carry', category: .dumbbell, target: .fullBody, isMine: true);

  setUp(() async {
    final service = MockExerciseService();
    final remote = MockRemoteExerciseService();
    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, squat, carry]));
    when(service.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    exercises = Exercises(
      remoteService: remote,
      service: service,
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    await exercises.init();

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  /// [template] at a phone's width, rebuilt whenever [changed] ticks — the
  /// way the editor rebuilds on every change to the plan.
  Future<void> pump(
    WidgetTester tester,
    Template template, {
    Listenable? changed,
    bool inDialog = false,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: changed ?? ValueNotifier(0),
              builder: (_, _) => switch (inDialog) {
                // a dialog sizes itself by its content's intrinsic sizes
                true => AlertDialog(
                  content: SingleChildScrollView(child: TemplateMuscles(exercises: template)),
                ),
                false => ListView(children: [TemplateMuscles(exercises: template)]),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final line = find.byKey(AppKeys.templateMuscles);
  final toggle = find.byKey(AppKeys.templateMusclesToggle);

  Template push() {
    final template = Template.empty(id: 'push', order: 0);
    template.add(bench)
      ..first.setType = .warmup
      ..add(ExerciseSet(bench, weight: 60, reps: 5))
      ..add(ExerciseSet(bench, weight: 60, reps: 5));
    return template;
  }

  testWidgets('is a line that unfolds into the figures, and folds back', (tester) async {
    preferences.setFeature(Feature.muscleMap, on: true);
    await pump(tester, push());

    expect(find.text('1 exercise · 2 sets'), findsOneWidget, reason: 'the warm-up is not counted');
    expect(find.byType(MuscleFigures), findsNothing, reason: 'never opened for the user');
    expect(tester.getSize(line).height, lessThanOrEqualTo(48), reason: 'a line, not a block');

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(MuscleFigures), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(MuscleFigures), findsNothing);
  });

  testWidgets('unfolds in a dialog too', (tester) async {
    preferences.setFeature(Feature.muscleMap, on: true);
    await pump(tester, push(), inDialog: true);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MuscleFigures), findsOneWidget);
    expect(tester.getSize(find.byType(MuscleFigures)).height, greaterThan(100));
  });

  testWidgets('follows the plan as it changes', (tester) async {
    preferences.setFeature(Feature.muscleMap, on: true);
    final template = push();
    final changed = ValueNotifier(0);
    addTearDown(changed.dispose);
    await pump(tester, template, changed: changed);

    template.add(squat);
    template.last.add(ExerciseSet(squat, weight: 100, reps: 5));
    changed.value++;
    await tester.pumpAndSettle();

    expect(find.text('2 exercises · 4 sets'), findsOneWidget);
  });

  testWidgets('keeps its line, with nothing to unfold, when nothing can be placed', (tester) async {
    preferences.setFeature(Feature.muscleMap, on: true);
    await pump(tester, Template.empty(id: 'mine', order: 0)..add(carry));

    expect(find.text('1 exercise · 1 set'), findsOneWidget);
    expect(toggle, findsNothing);
  });

  testWidgets('is not built for an empty plan', (tester) async {
    preferences.setFeature(Feature.muscleMap, on: true);
    await pump(tester, Template.empty(id: 'empty', order: 0));
    expect(line, findsNothing);
  });

  testWidgets('is not built while the muscle map is off', (tester) async {
    await pump(tester, push());
    expect(line, findsNothing);
  });

  testWidgets('is not built when the user left it out', (tester) async {
    preferences
      ..setFeature(Feature.muscleMap, on: true)
      ..setOption(.muscleMapTemplate, on: false);
    await pump(tester, push());
    expect(line, findsNothing);
  });

  testWidgets('announces itself as a button that expands', (tester) async {
    preferences.setFeature(Feature.muscleMap, on: true);
    await pump(tester, push());
    final handle = tester.ensureSemantics();

    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        label: '1 exercise · 2 sets',
        isButton: true,
        hasExpandedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        onTapHint: 'show the muscles',
      ),
    );
    handle.dispose();
  });
}
