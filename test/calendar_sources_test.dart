// A calendar day's workout made from a template or a past workout (#737),
// through the real app: started on today, logged on a past day.

import 'package:clock/clock.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/visual.dart' show dialogWidth;
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart' show repeatOf;
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  setUpAll(loadAppFonts);

  const phone = Size(390, 844);
  const tablet = Size(1194, 834);
  final now = DateTime(2026, 11, 20, 12);
  final tenth = DateTime(2026, 11, 10);
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final row = Exercise(name: 'Barbell Row', category: .barbell, target: .back);

  late MockLocalDatabase db;
  late MockApi api;

  /// Done on the 5th: bench with a note, 2 × 5 at 80, and a photo.
  Workout fifth() {
    final exercise = WorkoutExercise(starter: ExerciseSet(bench, weight: 80, reps: 5)..isCompleted = true)
      ..note = 'Pause on the chest'
      ..superset = 1
      ..add(ExerciseSet(bench, weight: 80, reps: 5)..isCompleted = true);
    final workout = Workout.fromExercises([exercise], name: 'Push', templateId: 't-old', programId: 'p-old')
      ..start = DateTime(2026, 11, 5, 9)
      ..note = 'Slept badly';
    return workout..finish(DateTime(2026, 11, 5, 10));
  }

  Template template(String name, {String? programId}) {
    final workout = Workout(name: name);
    workout.add(row).add(ExerciseSet(row, weight: 60, reps: 8));
    return Template.fromJson({
      ...Template.fromWorkout('t-$name', workout, 1).toMap(),
      'programId': ?programId,
    });
  }

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    stubStartup(db, api);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, row]));
    when(db.getExerciseNotes(any)).thenAnswer((_) async => {});
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
  });

  Future<void> launch(
    WidgetTester tester, {
    Size size = phone,
    bool logs = true,
    List<Workout> history = const [],
    List<Template> templates = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      ...pastOnboarding(),
      'feature-pastWorkouts': logs ? 'on' : 'off',
      'screen-historyView': 'calendar',
      'screen-historyView-at': '2026-11-01T00:00:00.000Z',
    });
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => history);
    when(db.getTemplates(any)).thenAnswer((_) async => templates);
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(mockUser: MockUser(uid: 'u1', isAnonymous: true), signedIn: true),
      settle: false,
    );
    await tester.pumpTimes();
    final context = tester.element(find.byType(MaterialApp));
    await Exercises.of(context).init();
    await Templates.of(context).init();
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.historyStack);
    await tester.pumpTimes();
  }

  Finder day(String label) =>
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);
  String said(DateTime date) => DateFormat.yMMMMEEEEd('en').format(date);
  String today() => '${said(DateTime(2026, 11, 20))}, today';
  String past() => '${said(tenth)}, log a workout on this day';

  Future<void> choose(WidgetTester tester, String label, Key way) async {
    await tester.tap(day(label));
    await tester.pumpTimes();
    await tester.tap(find.byKey(way));
    await tester.pumpTimes();
  }

  Workout logging(WidgetTester tester) => tester.widget<WorkoutEditor>(find.byType(WorkoutEditor)).copy;

  Future<void> next(WidgetTester tester) async {
    final l = L.of(tester.element(find.byType(HistoryPage)));
    expect(find.text(l.whenWasIt), findsOneWidget);
    await tester.tap(find.text(l.next));
    await tester.pumpTimes();
  }

  void testDay(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) => withClock(Clock.fixed(now), () => body(tester)));
  }

  test('a copy to do again brings what to do, and nothing of the day it was done', () {
    final done = fifth();
    final copy = repeatOf(done);

    expect(copy.id, isNot(done.id));
    expect(copy.name, 'Push');
    final exercise = copy.single;
    expect((exercise.note, exercise.superset), ('Pause on the chest', 1));
    expect(
      [for (final set in exercise) (set.weight, set.reps, set.isCompleted)],
      [
        for (final set in done.single) (set.weight, set.reps, false),
      ],
    );
    expect(exercise.first.id, isNot(done.single.first.id));
    expect((copy.templateId, copy.programId, copy.note, copy.synced), (null, null, null, false));
    expect(copy.pauses, isEmpty);
    expect(copy.images, isEmpty);
  });

  test('a copy has none of the photos, and takes none from the one it was made from', () {
    final done = Workout.fromJson({
      ...fifth().toMap(),
      'images': [
        {'id': 'i1', 'workoutId': 'w', 'url': 'https://example.com/a.png', 'key': 'a'},
      ],
    });
    final before = done.images?.length;
    expect(before, 1);
    expect(repeatOf(done).images, isEmpty);
    expect(done.images?.length, before);
  });

  for (final size in [phone, tablet]) {
    testDay('on today, a past workout copied starts, at $size', (tester) async {
      final done = fifth();
      await launch(tester, size: size, history: [done], logs: false);
      await choose(tester, today(), AppKeys.calendarFromWorkout);
      final sheet = tester.getRect(find.byKey(AppKeys.workoutChoices));
      expect(sheet.width, lessThanOrEqualTo(dialogWidth));
      expect(
        find.descendant(of: find.byKey(AppKeys.workoutChoices), matching: find.text('Bench Press')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(AppKeys.makeFromWorkout(done.id)));
      await tester.pumpTimes();

      final started = verify(db.startWorkout(captureAny, any)).captured.single as Workout;
      expect(started.id, isNot(done.id));
      expect(started.end, isNull);
      expect(started.single.exercise.name, 'Bench Press');
    });

    testDay('on today, a template starts, at $size', (tester) async {
      await launch(tester, size: size, templates: [template('Pull')], logs: false);
      await choose(tester, today(), AppKeys.calendarFromTemplate);
      expect(tester.getRect(find.byKey(AppKeys.templateChoices)).width, lessThanOrEqualTo(dialogWidth));
      await tester.tap(find.byKey(AppKeys.makeFromTemplate('t-Pull')));
      await tester.pumpTimes();

      final started = verify(db.startWorkout(captureAny, any)).captured.single as Workout;
      expect(started.templateId, 't-Pull');
      expect(started.single.exercise.name, 'Barbell Row');
    });
  }

  testDay('on a past day, a copy is logged on that day, not started', (tester) async {
    final done = fifth();
    await launch(tester, size: tablet, history: [done]);
    await choose(tester, past(), AppKeys.calendarFromWorkout);
    await tester.tap(find.byKey(AppKeys.makeFromWorkout(done.id)));
    await tester.pumpTimes();
    await next(tester);

    final copy = logging(tester);
    expect(copy.id, isNot(done.id));
    expect(DateUtils.dateOnly(copy.start.toLocal()), tenth);
    expect(DateUtils.dateOnly(copy.end!.toLocal()), tenth);
    expect(copy.single.note, 'Pause on the chest');
    expect(copy.single.every((set) => !set.isCompleted), isTrue);
    verifyNever(db.startWorkout(any, any));
  });

  testDay('on a past day, a template is laid out on that day', (tester) async {
    await launch(tester, size: tablet, templates: [template('Pull')]);
    await choose(tester, past(), AppKeys.calendarFromTemplate);
    await tester.tap(find.byKey(AppKeys.makeFromTemplate('t-Pull')));
    await tester.pumpTimes();
    await next(tester);

    final made = logging(tester);
    expect(made.templateId, 't-Pull');
    expect(DateUtils.dateOnly(made.start.toLocal()), tenth);
    verifyNever(db.startWorkout(any, any));
  });

  testDay('templates are under their folders, as the Workout tab files them', (tester) async {
    final folder = TemplateFolder(id: 'f1', name: 'Split');
    final filed = Template.fromJson({...template('Filed').toMap(), 'folder': folder.toMap()});
    when(db.getTemplateFolders(any)).thenAnswer((_) async => [folder]);
    await launch(tester, size: tablet, templates: [template('Loose'), filed]);
    await choose(tester, today(), AppKeys.calendarFromTemplate);

    final sheet = find.byKey(AppKeys.templateChoices);
    double top(String text) => tester.getTopLeft(find.descendant(of: sheet, matching: find.text(text))).dy;
    expect(top('Split'), lessThan(top('Filed')));
    expect(top('Filed'), lessThan(top('Loose')));
  });

  testDay('closing the list makes nothing', (tester) async {
    await launch(tester, size: tablet, templates: [template('Pull')]);
    await choose(tester, past(), AppKeys.calendarFromTemplate);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.templateChoices), findsNothing);
    expect(find.byType(WorkoutEditor), findsNothing);
    verifyNever(db.startWorkout(any, any));
  });

  testDay('no templates and no history: today only starts, a past day only logs', (tester) async {
    await launch(tester, size: tablet);
    await tester.tap(day(today()));
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.calendarStart), findsOneWidget);
    expect(find.byKey(AppKeys.calendarFromTemplate), findsNothing);
    expect(find.byKey(AppKeys.calendarFromWorkout), findsNothing);
    await tester.tapAt(const Offset(1100, 800));
    await tester.pumpTimes();

    await tester.tap(day(past()));
    await tester.pumpTimes();
    expect(find.text(L.of(tester.element(find.byType(HistoryPage))).whenWasIt), findsOneWidget);
  });

  testDay('a template with no sets is nothing to make a workout from', (tester) async {
    final empty = Template.fromJson({...template('Empty').toMap(), 'exercises': <Map>[]});
    await launch(tester, size: tablet, templates: [empty]);
    await tester.tap(day(today()));
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.calendarFromTemplate), findsNothing);
  });

  testDay('a workout started meanwhile is asked about before it is discarded', (tester) async {
    final done = fifth();
    await launch(tester, size: tablet, history: [done], logs: false);
    await choose(tester, today(), AppKeys.calendarFromWorkout);
    final workouts = Workouts.of(tester.element(find.byType(HistoryPage)));
    await workouts.startWorkout(source: .blank, name: 'Other');
    await tester.pumpTimes();
    await tester.tap(find.byKey(AppKeys.makeFromWorkout(done.id)));
    await tester.pumpTimes();
    final l = L.of(tester.element(find.byType(HistoryPage)));
    expect(find.text(l.cancelCurrentWorkoutTitle), findsOneWidget);
    expect(workouts.activeWorkout?.name, 'Other');
  });
}
