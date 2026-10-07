import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/shortcuts.dart';
import 'package:heart/core/utils/templates.dart';
import 'package:heart/presentation/navigation/system_shortcuts.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The platform's layer, remembering every list it was told.
class _Recorder implements SystemShortcuts {
  final told = <List<ShortcutTemplate>>[];
  final rests = <ShortcutRest?>[];

  @override
  Future<void> setTemplates(Iterable<ShortcutTemplate> templates) async {
    told.add(templates.toList());
  }

  @override
  Future<void> setRest(ShortcutRest? rest) async {
    rests.add(rest);
  }

  final sets = <ShortcutSet?>[];

  @override
  Future<void> setNextSet(ShortcutSet? set) async {
    sets.add(set);
  }
}

void main() {
  late Preferences preferences;
  late Templates templates;
  late Workouts workouts;
  late Timers timers;
  late Exercises exercises;
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late _Recorder recorder;

  Template template({required String id, required String name, int order = 0}) {
    return Template.fromWorkout(id, Workout(name: name), order);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    // wired as app.dart wires it; no user, so only the samples are read
    templates = Templates(
      service: db,
      remoteService: api,
      configService: cdn,
      folderService: LocalTemplateFolders(db),
      remoteFolderService: api,
      filingService: RemoteTemplateFiling(api),
    );
    workouts = Workouts(service: MockWorkoutService(), remoteService: MockRemoteWorkoutService())..userId = 'u1';
    final timersService = MockTimersService();
    when(
      timersService.setRestTimer(
        exerciseName: anyNamed('exerciseName'),
        userId: anyNamed('userId'),
        seconds: anyNamed('seconds'),
      ),
    ).thenAnswer((_) async {});
    timers = Timers(service: timersService)..userId = 'u1';
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    recorder = _Recorder();
  });

  tearDown(() {
    templates.dispose();
    preferences.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Templates>.value(value: templates),
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Timers>.value(value: timers),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => SystemShortcutsPresenter(shortcuts: recorder, child: child!),
          home: const Text('Any route'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('publishes the user\'s templates, then the samples, as they land', (tester) async {
    when(db.getTemplates(null)).thenAnswer((_) async => [template(id: 's1', name: 'Full Body')]);
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    await pump(tester);
    // nothing yet: told so, once
    expect(recorder.told, [<ShortcutTemplate>[]]);

    await templates.init();
    await tester.pump();

    expect(recorder.told.last, [const ShortcutTemplate(id: 's1', name: 'Full Body')]);
  });

  testWidgets('the same list is not told twice', (tester) async {
    when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    await pump(tester);
    await templates.init();
    await tester.pump();
    final before = recorder.told.length;

    // a repaint with nothing new
    preferences.setFeature(.rpe, on: true);
    await tester.pump();

    expect(recorder.told.length, before);
  });

  testWidgets('switched off, the assistant knows no template; on again, it does', (tester) async {
    when(db.getTemplates(null)).thenAnswer((_) async => [template(id: 's1', name: 'Push')]);
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    await pump(tester);
    await templates.init();
    await tester.pump();
    expect(recorder.told.last, isNotEmpty);

    preferences.setFeature(.shortcuts, on: false);
    await tester.pump();
    expect(recorder.told.last, isEmpty);

    preferences.setFeature(.shortcuts, on: true);
    await tester.pump();
    expect(recorder.told.last, [const ShortcutTemplate(id: 's1', name: 'Push')]);
  });

  testWidgets('a template without a name is left out', (tester) async {
    when(db.getTemplates(null)).thenAnswer(
      (_) async => [template(id: 's1', name: ' '), template(id: 's2', name: 'Pull', order: 1)],
    );
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    await pump(tester);
    await templates.init();
    await tester.pump();

    expect(recorder.told.last, [const ShortcutTemplate(id: 's2', name: 'Pull')]);
  });

  group('the rest a voice command acts on (#98)', () {
    final bench = Exercise.fromJson({
      'id': 'id-bench',
      'name': 'Bench Press (Barbell)',
      'category': 'Barbell',
      'target': 'Chest',
      'archived': false,
    });

    testWidgets('with no workout there is no rest to speak of', (tester) async {
      when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
      await pump(tester);
      expect(recorder.rests, [null]);
    });

    testWidgets('names the exercise the user is on, its rest setting, and the notification\'s words', (
      tester,
    ) async {
      when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
      final block = WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5))
        ..add(ExerciseSet(bench, weight: 62.5, reps: 5));
      final workout = Workout.fromExercises([block], name: 'Push day');
      await pump(tester);

      await timers.setRestTimer(bench.id, 90);
      await workouts.startWorkout(source: .template, template: workout);
      await tester.pump();

      final rest = recorder.rests.last;
      expect(rest?.workoutId, workout.id);
      expect(rest?.exerciseId, block.id);
      expect(rest?.seconds, 90);
      expect(rest?.title, 'Rest complete!');
      expect(rest?.body, '60 kg x 5', reason: 'the set up next: the first, nothing is ticked');
      expect(rest?.subtitle, contains('Bench Press'));

      // the same rest is not told twice
      final told = recorder.rests.length;
      workouts.notifyListeners();
      await tester.pump();
      expect(recorder.rests.length, told);
    });

    testWidgets('switched off, the assistant is told there is no rest', (tester) async {
      when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
      await pump(tester);
      final block = WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5));
      await workouts.startWorkout(
        source: .template,
        template: Workout.fromExercises([block], name: 'Push day'),
      );
      await tester.pump();
      expect(recorder.rests.last, isNotNull);

      preferences.setFeature(.shortcuts, on: false);
      await tester.pump();

      expect(recorder.rests.last, isNull);
    });
  });

  group('the set a voice command logs (#287)', () {
    final bench = Exercise.fromJson({
      'id': 'id-bench',
      'name': 'Bench Press (Barbell)',
      'category': 'Barbell',
      'target': 'Chest',
      'archived': false,
    });

    testWidgets('names the set up next with what it holds, in the unit it is shown in', (tester) async {
      when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
      await preferences.setWeightUnit(MeasurementUnit.imperial);
      final block = WorkoutExercise(starter: ExerciseSet(bench, weight: 100, reps: 5))..add(ExerciseSet(bench));
      final workout = Workout.fromExercises([block], name: 'Push day');
      await pump(tester);
      expect(recorder.sets, [null]);

      await workouts.startWorkout(source: .template, template: workout);
      await tester.pump();

      final set = recorder.sets.last;
      expect(set?.setId, block.first.id);
      expect(set?.exerciseName, 'Bench Press (Barbell)');
      expect(set?.weighted, isTrue);
      expect(set?.counted, isTrue);
      expect(set?.unit, 'lbs');
      expect(set?.weight, closeTo(220.5, 0.1), reason: '100 kg, said in pounds');
      expect(set?.reps, 5);
      expect(set?.completable, isTrue);

      // ticked: the next one, which holds nothing yet and cannot be ticked as it stands
      workouts.markSetAsComplete(block, block.first);
      await tester.pump();
      expect(recorder.sets.last?.setId, block.toList()[1].id);
      expect(recorder.sets.last?.weight, isNull);
      expect(recorder.sets.last?.completable, isFalse);
    });

    testWidgets('with every set done there is nothing to log', (tester) async {
      when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
      final block = WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5));
      final workout = Workout.fromExercises([block], name: 'Push day');
      await pump(tester);
      await workouts.startWorkout(source: .template, template: workout);
      await tester.pump();
      expect(recorder.sets.last, isNotNull);

      workouts.markSetAsComplete(block, block.first);
      await tester.pump();

      expect(recorder.sets.last, isNull);
    });
  });
}
