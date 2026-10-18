// Programs on the Workout tab (#345, #347, #348): the ask, the without state,
// the band, the program page and making one from a folder. The tab's pieces
// are private to the `workout.dart` library, so these drive the real app
// through the router, as `templates_test.dart` does.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/calendar.dart';
import 'package:heart/core/utils/program_calendar.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/workout/workout.dart' show ProgramPage;
import 'package:heart/presentation/widgets/feature_offer.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart' show WorkoutDetailKeys;
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  const userId = 'u1';
  final folder = TemplateFolder(id: 'f1', name: 'Split');

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  Template template(String id, int order, String name, {String? programId}) {
    final draft = Template.empty(id: id, order: order, folder: folder)
      ..name = name
      ..add(bench);
    return Template.fromJson({...draft.toMap(), 'programId': ?programId});
  }

  final program = Program(
    id: 'p1',
    name: 'Split',
    perWeek: 3,
    weeks: 8,
    sessions: const ['t1', 't2'],
    createdAt: DateTime.utc(2026, 10, 1),
  );

  void answer(FeatureAnswer answer) {
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-programs': answer.name});
  }

  /// [program] on the device and on the server, with its two sessions filed
  /// in the folder.
  void withProgram() {
    when(db.getPrograms(userId)).thenAnswer((_) async => [program]);
    when(api.getPrograms()).thenAnswer((_) async => [program]);
    when(db.getTemplates(userId)).thenAnswer(
      (_) async => [template('t1', 0, 'Push', programId: 'p1'), template('t2', 1, 'Pull', programId: 'p1')],
    );
  }

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});

    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
    when(db.getTemplates(userId)).thenAnswer((_) async => [template('t1', 0, 'Push'), template('t2', 1, 'Pull')]);
    when(api.getTemplates()).thenAnswer((_) async => null);
    when(db.getTemplateFolders(userId)).thenAnswer((_) async => [folder]);
    when(api.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => [folder]);
    when(db.storeTemplateFolders(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(db.storeTemplates(any, userId: anyNamed('userId'))).thenAnswer((_) async {});

    when(db.getPrograms(userId)).thenAnswer((_) async => <Program>[]);
    when(db.getProgramActions(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramBases(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramMarks(userId, any)).thenAnswer((_) async => []);
    when(db.storePrograms(any, any)).thenAnswer((_) async {});
    when(db.storeProgram(any, any)).thenAnswer((_) async {});
    when(db.storeProgramActions(any, any)).thenAnswer((_) async {});
    when(db.storeProgramBases(any, any)).thenAnswer((_) async {});
    when(db.storeProgramAction(any)).thenAnswer((_) async {});
    when(db.deleteProgramAction(any)).thenAnswer((_) async {});
    when(db.deleteProgram(any, keepTemplates: anyNamed('keepTemplates'))).thenAnswer((_) async {});
    when(api.getPrograms()).thenAnswer((_) async => <Program>[]);
    when(api.getProgramActions(any)).thenAnswer((_) async => []);
    when(api.getProgramBases(any)).thenAnswer((_) async => []);
    when(api.replayProgram(any, sessions: anyNamed('sessions'))).thenAnswer(
      (i) async => (row: i.positionalArguments.single as Program, created: true),
    );
    when(api.replayProgramAction(any)).thenAnswer(
      (i) async => (row: i.positionalArguments.single as ProgramAction, created: true),
    );
    when(api.deleteProgramAction(any, any)).thenAnswer((_) async {});
    when(api.editProgram(any)).thenAnswer((i) async => i.positionalArguments.single as Program);
    when(api.deleteProgram(any, keepTemplates: anyNamed('keepTemplates'))).thenAnswer((_) async {});
    when(db.getSkips(userId)).thenAnswer((_) async => <TrainingSkip>[]);
    when(db.storeSkips(any, any)).thenAnswer((_) async {});
    when(db.storeSkip(any, any)).thenAnswer((_) async {});
    when(db.deleteSkip(any)).thenAnswer((_) async {});
    when(api.getSkips()).thenAnswer((_) async => <TrainingSkip>[]);
    when(api.replaySkip(any))
        .thenAnswer((i) async => (row: i.positionalArguments.single as TrainingSkip, created: true));
    when(api.deleteSkip(any)).thenAnswer((_) async {});
  });

  /// Signs in and lands on the Workout tab with templates and programs read.
  /// Both notifiers are initialised directly: the app's own startup chain runs
  /// in the root zone, which a widget test never pumps (see templates_test).
  Future<void> openWorkoutTab(WidgetTester tester, {DeviceCalendar? calendar}) async {
    await const TestAppHarness().pumpHeartApp(
      tester,
      calendar: calendar,
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
    final context = tester.element(find.byType(MaterialApp));
    final templates = Templates.of(context);
    await templates.init();
    templates.notifyListeners();
    await Programs.of(context).init();
    await tester.pumpTimes();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpTimes();
  }

  group('on by default (#345)', () {
    testWidgets('never answered, Programs is on: the header and the way in, and no ask', (tester) async {
      answer(.unasked);
      await openWorkoutTab(tester);
      await tester.scrollUntilVisible(
        find.byKey(AppKeys.programsFromFolder),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(AppKeys.programsFromFolder), findsOneWidget);
      expect(find.byType(FeatureOffer), findsNothing);
    });

    testWidgets('off, the tab and the folder menu are as before programs', (tester) async {
      answer(.off);
      withProgram();
      await openWorkoutTab(tester);

      expect(find.byKey(AppKeys.programBand('p1')), findsNothing);
      expect(find.byKey(AppKeys.programsFromFolder), findsNothing);

      await tester.tap(find.byTooltip('More options').first);
      await tester.pumpTimes();
      expect(find.text('Make a program'), findsNothing);
    });
  });

  group('the band (#347)', () {
    testWidgets('says where the program stands and starts what is next', (tester) async {
      answer(.on);
      withProgram();
      await openWorkoutTab(tester);

      final band = find.byKey(AppKeys.programBand('p1'));
      expect(band, findsOneWidget);
      // the week, and when the program would end at this pace (#F33)
      expect(find.descendant(of: band, matching: find.textContaining(RegExp(r'^Week 1 of 8 · ends '))), findsOneWidget);
      expect(find.descendant(of: band, matching: find.text('0 of 3 this week')), findsOneWidget);

      await tester.tapByKey(AppKeys.programStart('p1'));
      await tester.pumpTimes();

      final started = verify(db.startWorkout(captureAny, any)).captured.single as Workout;
      expect(started.templateId, 't1');
      expect(started.programId, 'p1');
    });

    testWidgets('its sessions stay in their folder, as they were', (tester) async {
      answer(.on);
      withProgram();
      await openWorkoutTab(tester);

      // once on the band's strip, once as a card in the folder
      expect(find.text('Push'), findsNWidgets(2));
    });
  });

  group('not today (#312)', () {
    testWidgets('one tap sets the next session aside, the band moves on, and Undo takes it back', (tester) async {
      answer(.on);
      withProgram();
      await openWorkoutTab(tester);

      await tester.tapByKey(AppKeys.programNotToday('p1'));
      await tester.pumpTimes();

      final skip = verify(db.storeSkip(captureAny, userId)).captured.first as TrainingSkip;
      expect((skip.templateId, skip.programId), ('t1', 'p1'));
      verify(api.replaySkip(any)).called(1);
      expect(find.text('Push sits this one out'), findsOneWidget);
      // done in the cycle, by a skip: the strip says which, and Pull is next
      expect(
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Push, skipped'),
        findsOneWidget,
      );
      expect(find.text('Start Pull'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpTimes();

      verify(db.deleteSkip(skip.id)).called(1);
      verify(api.deleteSkip(skip.id)).called(1);
      expect(find.text('Start Push'), findsOneWidget);
    });

    testWidgets("on the program's page, the Undo is there at once, before the server answers", (tester) async {
      answer(.on);
      withProgram();
      // a server that has not answered yet
      final answered = Completer<({TrainingSkip row, bool created})>();
      when(api.replaySkip(any)).thenAnswer((_) => answered.future);
      await openWorkoutTab(tester);
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();

      await tester.tapByKey(AppKeys.programNotToday('p1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ProgramPage), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      answered.complete((row: verify(db.storeSkip(captureAny, userId)).captured.first as TrainingSkip, created: true));
      await tester.pumpTimes();
    });

    testWidgets('a skipped day is in History, and gone from it with Programs off', (tester) async {
      answer(.on);
      withProgram();
      await openWorkoutTab(tester);
      await tester.tapByKey(AppKeys.programNotToday('p1'));
      await tester.pumpTimes();
      final skip = verify(db.storeSkip(captureAny, userId)).captured.first as TrainingSkip;

      await tester.tapByKey(AppKeys.historyStack);
      await tester.pumpTimes();

      final row = find.byKey(AppKeys.historySkip(skip.id));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Push')), findsOneWidget);

      Preferences.of(tester.element(row)).setFeature(.programs, on: false);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.historySkip(skip.id)), findsNothing);
    });

    testWidgets('a paused program has nothing due, so nothing to set aside', (tester) async {
      answer(.on);
      withProgram();
      when(db.getProgramActions(userId, programId: anyNamed('programId'))).thenAnswer(
        (_) async => [ProgramAction(id: 'a1', programId: 'p1', kind: .pause, at: DateTime.utc(2026, 10, 2))],
      );
      when(api.getProgramActions(any)).thenAnswer(
        (_) async => [ProgramAction(id: 'a1', programId: 'p1', kind: .pause, at: DateTime.utc(2026, 10, 2))],
      );
      await openWorkoutTab(tester);

      expect(find.byKey(AppKeys.programNotToday('p1')), findsNothing);
      expect(find.byKey(AppKeys.programStart('p1')), findsOneWidget);
    });
  });

  group('the program page (#347)', () {
    Future<void> openPage(WidgetTester tester) async {
      answer(.on);
      withProgram();
      await openWorkoutTab(tester);
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();
    }

    testWidgets("the band's Start lines up with its week, at the card's right inset", (tester) async {
      answer(.on);
      withProgram();
      await openWorkoutTab(tester);
      final band = find.byKey(AppKeys.programBand('p1'));
      final start = tester.getRect(find.byKey(AppKeys.programStart('p1')));
      final card = tester.getRect(band);

      final week = tester.getRect(find.descendant(of: band, matching: find.textContaining('Week')));
      expect(start.right, closeTo(card.right - 12, 1));
      expect(start.right, closeTo(week.right, 1));
    });

    testWidgets("a program's folder is marked, and the mark opens the program over the tab", (tester) async {
      answer(.on);
      withProgram();
      await openWorkoutTab(tester);
      final mark = find.byKey(AppKeys.partOfProgram('p1'));
      await scrollTo(tester, mark);
      expect(mark, findsOneWidget);
      // beside the folder's ⋯, as one trailing pair, a full finger's size
      final menu = tester.getRect(
        find.ancestor(of: find.byIcon(Icons.more_horiz), matching: find.byType(PopupMenuButton<VoidCallback>)).first,
      );
      final markRect = tester.getRect(mark);
      expect(menu.left - markRect.right, lessThan(4));
      expect(markRect.height, greaterThanOrEqualTo(44));

      await tester.tap(mark);
      await tester.pumpTimes();
      expect(find.byType(ProgramPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpTimes();
      expect(find.byType(ProgramPage), findsNothing);
      expect(mark, findsOneWidget);
    });

    testWidgets('a session under way is said at the top, and returns to its workout', (tester) async {
      when(db.startWorkout(any, any)).thenAnswer((_) async {});
      await openPage(tester);
      expect(find.byKey(AppKeys.programInProgress), findsNothing);

      final context = tester.element(find.byType(ProgramPage));
      await Workouts.of(context).startWorkout(
        source: .program,
        template: Workout.fromExercises([], name: 'Push', programId: 'p1'),
      );
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.programInProgress), findsOneWidget);
      expect(find.text('In progress: Push'), findsOneWidget);
    });

    testWidgets("an exercise's charts say the program that trains it", (tester) async {
      answer(.on);
      withProgram();
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
      await openWorkoutTab(tester);
      final context = tester.element(find.byType(MaterialApp));
      await Exercises.of(context).init();
      HeartRouter.of(context).config.go('/exercises/${bench.id}?tab=charts');
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.exerciseInProgram), findsOneWidget);
      expect(find.text('In your program, Split'), findsOneWidget);

      // the program over the chart, and Back is the chart again (#F36)
      await tester.tapByKey(AppKeys.exerciseInProgram);
      await tester.pumpTimes();
      expect(find.byType(ProgramPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpTimes();
      expect(find.byType(ProgramPage), findsNothing);
      expect(find.byKey(AppKeys.exerciseInProgram), findsOneWidget);
    });

    testWidgets('the sessions are joined by a rail through their icons, one sequence', (tester) async {
      await openPage(tester);
      await scrollTo(tester, find.text('Pull'));

      final rails = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_Rail',
      );
      // Push and Pull: one runs down from the first, the other up into it
      expect(rails, findsNWidgets(2));
    });

    testWidgets('a steer lands at once, with an Undo', (tester) async {
      await openPage(tester);

      await tester.tap(find.text('Repeat this week'));
      await tester.pumpTimes();

      final action = verify(db.storeProgramAction(captureAny)).captured.first as ProgramAction;
      expect(action.kind, ProgramActionKind.repeat);
      expect(find.text('This week runs again'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpTimes();
      verify(db.deleteProgramAction(action.id)).called(1);
    });

    testWidgets("a lift's working weight shows under its rule, and the user can set it", (tester) async {
      final growing = program.copyWith(rules: {bench.id: const AddWeight(step: 2.5)});
      answer(.on);
      withProgram();
      when(db.getPrograms(userId)).thenAnswer((_) async => [growing]);
      when(api.getPrograms()).thenAnswer((_) async => [growing]);
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
      when(db.storeProgramBase(any)).thenAnswer((_) async {});
      await openWorkoutTab(tester);
      await Exercises.of(tester.element(find.byType(MaterialApp))).init();
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();

      final edit = find.byKey(WorkoutDetailKeys.programBaseEdit(bench.id));
      await scrollTo(tester, edit);
      expect(find.text('No weight yet: its first session sets one'), findsOneWidget);

      await tester.tap(edit);
      await tester.pumpTimes();
      await tester.enterText(find.byKey(WorkoutDetailKeys.programBaseField), '70');
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.programBaseSave);
      await tester.pumpTimes();

      final base = verify(db.storeProgramBase(captureAny)).captured.last as ProgramBase;
      // the user's own word: no workout, no action behind it
      expect((base.exerciseId, base.workoutId, base.actionId), (bench.id, null, null));
      // typed in the unit shown, here pounds, and stored in kilograms
      expect(base.value, closeTo(31.75, .01));
      expect(find.text('Working weight: 70 lbs'), findsOneWidget);
    });

    testWidgets('How it grows says when the program goes lighter', (tester) async {
      final lighter = program.copyWith(deload: const Deload(every: 4));
      answer(.on);
      withProgram();
      when(db.getPrograms(userId)).thenAnswer((_) async => [lighter]);
      when(api.getPrograms()).thenAnswer((_) async => [lighter]);
      await openWorkoutTab(tester);
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();

      // under the sessions and the calendar's row (#391)
      await scrollTo(tester, find.text('How it grows'));
      expect(find.text('How it grows'), findsOneWidget);
      expect(find.text('Every 4 weeks, a lighter one: 90% of the weight, 50% of the sets'), findsOneWidget);
    });

    testWidgets('How it grows reads a stages rule, and an occurrence with its own as itself (#350)', (tester) async {
      final push = template('t1', 0, 'Push', programId: 'p1');
      final tiers = program.copyWith(
        rules: {
          bench.id: const AddWeight(step: 2.5),
          // Push's bench, on a rule of its own
          push.first.id: const Stages(
            stages: [
              Stage(sets: 5, reps: 3, amrap: true),
              Stage(sets: 6, reps: 2, amrap: true),
              Stage(sets: 10, reps: 1),
            ],
            step: 2.5,
            miss: MissRule(after: 1, cut: 0.15),
          ),
        },
      );
      answer(.on);
      withProgram();
      when(db.getPrograms(userId)).thenAnswer((_) async => [tiers]);
      when(api.getPrograms()).thenAnswer((_) async => [tiers]);
      when(db.getTemplates(userId)).thenAnswer((_) async => [push, template('t2', 1, 'Pull', programId: 'p1')]);
      await openWorkoutTab(tester);
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();

      await scrollTo(tester, find.text('How it grows'));
      expect(find.text('Bench Press · Push'), findsOneWidget);
      final stages = find.textContaining('5×3+ → 6×2+ → 10×1, up ');
      expect(stages, findsOneWidget);
      expect(tester.widget<Text>(stages).data, endsWith('when a session makes them; one short moves on to the next'));
      expect(find.text('Short after the last, it starts over from the first, 15% lighter'), findsOneWidget);
    });

    testWidgets('a lighter week is asked for like any steer, and then not offered again (#350)', (tester) async {
      await openPage(tester);

      await tester.tap(find.text('Lighter week'));
      await tester.pumpTimes();

      final action = verify(db.storeProgramAction(captureAny)).captured.first as ProgramAction;
      expect(action.kind, ProgramActionKind.lighter);
      expect(find.text('This week goes lighter'), findsOneWidget);
      expect(find.text('Lighter week'), findsNothing);
    });

    testWidgets('one step at a time: a second tap while one is on its way records nothing', (tester) async {
      await openPage(tester);
      final reply = Completer<Replayed<ProgramAction>>();
      when(api.replayProgramAction(any)).thenAnswer((_) => reply.future);

      await tester.tap(find.text('Repeat this week'));
      await tester.pump();
      await tester.tap(find.text('Repeat this week'));
      await tester.pump();
      verify(db.storeProgramAction(any)).called(1);

      final action = verify(api.replayProgramAction(captureAny)).captured.single as ProgramAction;
      reply.complete((row: action, created: true));
      await tester.pumpTimes();
      expect(find.text('This week runs again'), findsOneWidget);
    });

    testWidgets('an edit saves onto the program as it is by then', (tester) async {
      await openPage(tester);
      await tester.tap(find.byTooltip('Edit program'));
      await tester.pumpTimes();
      expect(find.text('Edit program'), findsWidgets);

      // a read from elsewhere archives it while the form is open
      final programs = Programs.of(tester.element(find.byType(MaterialApp)));
      await programs.update(programs.lookup('p1')!.copyWith(archived: true));
      await tester.pumpTimes();

      await tester.enterText(find.byType(TextField), 'Split, again');
      await tester.tap(find.text('Save'));
      await tester.pumpTimes();

      final saved = verify(db.storeProgram(captureAny, userId)).captured.last as Program;
      expect((saved.name, saved.archived), ('Split, again', true));
    });

    testWidgets('an edit can take the weekly target and the fixed length away', (tester) async {
      await openPage(tester);
      await tester.tap(find.byTooltip('Edit program'));
      await tester.pumpTimes();

      for (var tap = 0; tap < 3; tap++) {
        await tester.tap(find.byTooltip('Fewer').first);
        await tester.pump();
      }
      expect(find.text('No target'), findsOneWidget);
      await tester.tap(find.text('Ongoing'));
      await tester.pumpTimes();
      await tester.tap(find.text('Save'));
      await tester.pumpTimes();

      final saved = verify(db.storeProgram(captureAny, userId)).captured.last as Program;
      expect((saved.perWeek, saved.weeks), (null, null));
      verify(api.editProgram(argThat(predicate<Program>((p) => p.perWeek == null && p.weeks == null)))).called(1);
    });

    testWidgets('an edit of a program that is gone is a bare page, never a new one', (tester) async {
      await openPage(tester);
      await tester.tap(find.byTooltip('Edit program'));
      await tester.pumpTimes();

      final programs = Programs.of(tester.element(find.byType(MaterialApp)));
      await programs.delete(programs.lookup('p1')!, keepTemplates: true);
      await tester.pumpTimes();

      expect(find.text('New program'), findsNothing);
      expect(find.text('Start program'), findsNothing);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('switched off under it, the page leaves for the tab', (tester) async {
      await openPage(tester);
      expect(find.text('Repeat this week'), findsOneWidget);

      Preferences.of(tester.element(find.byType(MaterialApp))).setFeature(.programs, on: false);
      await tester.pumpTimes();

      expect(find.text('Repeat this week'), findsNothing);
      expect(find.byKey(AppKeys.programBand('p1')), findsNothing);
    });

    testWidgets('deleting keeps the templates unless told otherwise', (tester) async {
      await openPage(tester);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpTimes();
      await tester.tap(find.text('Delete program'));
      await tester.pumpTimes();
      expect(find.text('Delete Split?'), findsOneWidget);

      await tester.tap(find.text('Keep the templates'));
      await tester.pumpTimes();

      verify(db.deleteProgram('p1', keepTemplates: true)).called(1);
      verify(api.deleteProgram('p1', keepTemplates: true)).called(1);
    });
  });

  group('not today on any day (#312)', () {
    void features({bool programs = false, bool notToday = true}) {
      SharedPreferences.setMockInitialValues({
        ...pastOnboarding(),
        'feature-programs': (programs ? FeatureAnswer.on : FeatureAnswer.off).name,
        'feature-notToday': (notToday ? FeatureAnswer.on : FeatureAnswer.off).name,
      });
    }

    testWidgets('one tap sets today aside; a reason is one more tap, and Undo takes it back', (tester) async {
      features();
      await openWorkoutTab(tester);

      await tester.tapByKey(AppKeys.notTodayDay);
      await tester.pumpTimes();

      final day = verify(db.storeSkip(captureAny, userId)).captured.first as TrainingSkip;
      expect((day.programId, day.templateId, day.reason), (null, null, null));
      verify(api.replaySkip(any)).called(1);
      expect(find.byKey(AppKeys.skipSheet), findsOneWidget);

      await tester.tapByKey(AppKeys.skipReason('busy'));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.skipSheet), findsNothing);
      verify(db.deleteSkip(day.id)).called(1);
      final given = verify(db.storeSkip(captureAny, userId)).captured.last as TrainingSkip;
      expect((given.at, given.reason, given.programId), (day.at, 'busy', null));

      // today is set aside: the tab says so, and asks nothing more
      expect(find.byKey(AppKeys.notTodayDay), findsNothing);
      await tester.tapByKey(AppKeys.notTodayUndo);
      await tester.pumpTimes();
      verify(db.deleteSkip(given.id)).called(1);
      expect(find.byKey(AppKeys.notTodayDay), findsOneWidget);
    });

    testWidgets('dismissing the sheet is no reason, and nothing else', (tester) async {
      features();
      await openWorkoutTab(tester);
      await tester.tapByKey(AppKeys.notTodayDay);
      await tester.pumpTimes();
      clearInteractions(db);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.skipSheet), findsNothing);
      verifyNever(db.deleteSkip(any));
      expect(find.byKey(AppKeys.notTodayUndo), findsOneWidget);
    });

    testWidgets('off, the tab is as it was', (tester) async {
      features(notToday: false);
      await openWorkoutTab(tester);

      expect(find.byKey(AppKeys.notTodayDay), findsNothing);
    });

    testWidgets('a program skip offers its reason too while Not today is on', (tester) async {
      features(programs: true);
      withProgram();
      await openWorkoutTab(tester);

      await tester.tapByKey(AppKeys.programNotToday('p1'));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.skipSheet), findsOneWidget);
      expect(find.text('Push sits this one out'), findsOneWidget);
    });

    testWidgets('History lists the day with its reason; its page says what the day looked like', (tester) async {
      final at = DateTime.utc(2026, 10, 8, 18);
      final day = TrainingSkip(id: 'd1', at: at, reason: 'tired');
      when(db.getSkips(userId)).thenAnswer((_) async => [day]);
      when(api.getSkips()).thenAnswer((_) async => [day]);
      when(db.getLensSets(any, any, userId: anyNamed('userId'))).thenAnswer(
        (_) async => [
          (
            workoutId: 'w1',
            exerciseId: 'bench',
            start: DateTime.utc(2026, 10, 7, 8),
            movement: Movement.empty(),
            muscles: MuscleTagging.empty(),
            target: Target.chest,
            sets: 12,
          ),
        ],
      );
      features();
      await openWorkoutTab(tester);

      await tester.tapByKey(AppKeys.historyStack);
      await tester.pumpTimes();
      final row = find.byKey(AppKeys.historySkip('d1'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('Tired')), findsOneWidget);

      await tester.tap(row);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.skipPage), findsOneWidget);
      expect(find.text('Tired'), findsOneWidget);
      expect(find.text('1 day since the last workout'), findsOneWidget);
      expect(find.text('12 sets in the week before'), findsOneWidget);
      expect(find.textContaining('Still recovering'), findsOneWidget);

      Preferences.of(tester.element(find.byType(MaterialApp))).setFeature(.notToday, on: false);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.skipThatDay), findsNothing);
    });
  });

  group("a program's goals (#353)", () {
    const benchId = 'bench-1';
    final start = DateTime.utc(2026, 10, 1);

    Future<void> openPage(WidgetTester tester, Program running, {List<ProgramBase> bases = const []}) async {
      answer(.on);
      withProgram();
      when(db.getPrograms(userId)).thenAnswer((_) async => [running]);
      when(api.getPrograms()).thenAnswer((_) async => [running]);
      when(db.getProgramBases(userId, programId: anyNamed('programId'))).thenAnswer((_) async => bases);
      when(api.getProgramBases(any)).thenAnswer((_) async => bases);
      await openWorkoutTab(tester);
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();
    }

    testWidgets('it shows what it implies, with where each lands at this pace', (tester) async {
      final running = program.copyWith(rules: {benchId: const AddWeight(step: 2.5)});
      await openPage(
        tester,
        running,
        bases: [ProgramBase(id: 'b1', programId: 'p1', exerciseId: benchId, value: 60, at: start)],
      );

      await scrollTo(tester, find.byKey(AppKeys.programGoals));
      expect(find.byKey(AppKeys.goalRow('program:p1:workouts')), findsOneWidget);
      // 60 + 2.5 a week over eight weeks, from week 1: on track for the last
      expect(find.byKey(AppKeys.goalRow('program:p1:$benchId')), findsOneWidget);
      expect(find.textContaining('On track for week 8'), findsOneWidget);
      // nothing is written behind the user's back
      verifyNever(db.createGoal(any, any));
    });

    testWidgets('a goal on a pattern none of its sessions train is told before anything is asked', (tester) async {
      when(db.createGoal(any, any)).thenAnswer((i) async {
        final goal = i.positionalArguments.first as Goal;
        return Goal(id: 'g1', metric: goal.metric, pattern: goal.pattern, cadence: goal.cadence, stages: goal.stages);
      });
      when(db.reconcileGoalId(any, any, any)).thenAnswer((_) async {});
      when(api.createGoal(any, any)).thenAnswer((i) async => i.positionalArguments.first as Goal);
      await openPage(tester, program);
      final goals = Goals.of(tester.element(find.byType(MaterialApp)))..userId = userId;
      await goals.create(
        Goal(metric: .sets, pattern: 'vertical_pull', cadence: .week, stages: [GoalStage(target: 10)]),
      );
      await tester.pumpTimes();

      await scrollTo(tester, find.byKey(AppKeys.programGoals));
      expect(find.textContaining('Nothing here trains'), findsOneWidget);
    });

    testWidgets('at the end, one not reached is kept as a goal, and reached ones run it again', (tester) async {
      // one week, and both its sessions done: finished
      final short = program.copyWith(weeks: 1, rules: {benchId: const AddWeight(step: 2.5)});
      when(db.getProgramMarks(userId, any)).thenAnswer(
        (_) async => [
          ProgramMark(templateId: 't1', at: start.add(const Duration(days: 1)), isWorkout: true),
          ProgramMark(templateId: 't2', at: start.add(const Duration(days: 2)), isWorkout: true),
        ],
      );
      // the mirror mints the id, as the database does
      when(db.createGoal(any, any)).thenAnswer((i) async {
        final goal = i.positionalArguments.first as Goal;
        return Goal(id: 'g1', metric: goal.metric, cadence: goal.cadence, stages: goal.stages);
      });
      when(db.reconcileGoalId(any, any, any)).thenAnswer((_) async {});
      when(api.createGoal(any, any)).thenAnswer((i) async => i.positionalArguments.first as Goal);
      await openPage(
        tester,
        short,
        bases: [
          ProgramBase(id: 'b1', programId: 'p1', exerciseId: benchId, value: 60, at: start),
          ProgramBase(
            id: 'b2',
            programId: 'p1',
            exerciseId: benchId,
            value: 62.5,
            at: start.add(const Duration(days: 2)),
          ),
        ],
      );
      Goals.of(tester.element(find.byType(MaterialApp))).userId = userId;

      await scrollTo(tester, find.byKey(AppKeys.programAgain));
      // the weight reached its 62.5; the three a week is no ratchet to reach
      expect(find.byKey(AppKeys.programGoalKeep('program:p1:$benchId')), findsNothing);
      await tester.tap(find.byKey(AppKeys.programGoalKeep('program:p1:workouts')));
      await tester.pumpTimes();
      final kept = verify(db.createGoal(captureAny, userId)).captured.single as Goal;
      expect(kept.id, isNull);
      expect(kept.metric, GoalMetric.workouts);
      expect(find.text('Kept as a goal'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.programAgain));
      await tester.pumpTimes();
      final again = verify(db.storeProgramAction(captureAny)).captured.last as ProgramAction;
      expect(again.kind, ProgramActionKind.replay);
      expect(again.week, 1);
    });
  });

  group('from a folder (#348)', () {
    testWidgets('one screen, and the folder\'s templates become the sessions in order', (tester) async {
      answer(.on);
      await openWorkoutTab(tester);

      await tester.tap(find.byTooltip('More options').first);
      await tester.pumpTimes();
      await tester.tap(find.text('Make a program'));
      await tester.pumpTimes();

      expect(find.text('New program'), findsOneWidget);
      expect(find.text('1. Push'), findsOneWidget);
      expect(find.text('2. Pull'), findsOneWidget);

      await tester.tap(find.text('Start program'));
      await tester.pumpTimes();

      final saved = verify(db.storeProgram(captureAny, userId)).captured.last as Program;
      expect(saved.name, 'Split');
      expect(saved.sessions, ['t1', 't2']);
      expect(saved.perWeek, 2);
      expect(saved.weeks, 8);
      final sessions = verify(db.storeTemplates(captureAny, userId: userId)).captured.last as Iterable<Template>;
      expect(sessions.map((session) => session.programId).toSet(), {saved.id});
      // back on the tab, with the program's band where the ask led
      expect(find.byKey(AppKeys.programBand(saved.id)), findsOneWidget);
    });
  });

  group('in the calendar (#391)', () {
    Future<void> openPage(WidgetTester tester, {required DeviceCalendar calendar}) async {
      // Programs never answered: on by default, the calendar with it
      SharedPreferences.setMockInitialValues(pastOnboarding());
      withProgram();
      await openWorkoutTab(tester, calendar: calendar);
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();
    }

    testWidgets('a row on the page; a calendar and days put the sessions in it, titled one plain word', (
      tester,
    ) async {
      final calendar = _Calendar();
      await openPage(tester, calendar: calendar);
      await scrollTo(tester, find.byKey(AppKeys.programCalendarRow));
      // nothing asks the OS until the user opens the setup
      expect(calendar.listed, 0);

      await tester.tapByKey(AppKeys.programCalendarRow);
      await tester.pumpTimes();
      expect(calendar.listed, 1);
      // what an event will say, before anything is saved
      expect(find.textContaining('Every event is called just “Training”'), findsOneWidget);
      // calendars under their accounts; one Heart cannot write to is there,
      // greyed, saying why
      expect(find.text('iCloud'), findsOneWidget);
      expect(find.text("Read-only: Heart can't add to it"), findsOneWidget);
      await tester.ensureVisible(find.byKey(AppKeys.programCalendarChoice('c2')));
      expect(tester.widget<ListTile>(find.byKey(AppKeys.programCalendarChoice('c2'))).enabled, isFalse);
      // the iPhone's hint about Google calendars is the iPhone's alone
      expect(find.byKey(AppKeys.programCalendarSettings), findsNothing);

      // every day, so the next session falls today
      for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) {
        final toggle = find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == day);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
      }
      await tester.ensureVisible(find.byKey(AppKeys.programCalendarChoice('c1')));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.programCalendarChoice('c1'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.programCalendarSave);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.programCalendarSave), findsNothing, reason: 'saved and closed');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpTimes();

      final edited = verify(api.editProgram(captureAny)).captured.last as Program;
      expect(edited.days, {1, 2, 3, 4, 5, 6, 7});
      expect(calendar.events, isNotEmpty);
      final (calendarId, first) = calendar.events.values.first;
      expect(calendarId, 'c1');
      // the same neutral word on every event, whatever the program is called
      expect(calendar.events.values.map((event) => event.$2.title).toSet(), {'Training'});
      expect(first.description, contains('Split · Push'));
      expect(first.url, endsWith('/workout/programs/p1/sessions/t1?week=1'));
      expect(first.time, isNull);
      expect(find.byKey(AppKeys.programCalendarRow), findsOneWidget);
    });

    testWidgets('on a phone, Remove has a line of its own and Cancel sits with Save', (tester) async {
      final calendar = _Calendar();
      await openPage(tester, calendar: calendar);
      final context = tester.element(find.byType(Scaffold).last);
      await ProgramCalendars.of(context).set('p1', (calendarId: 'c1', calendar: 'Home', time: null));
      await tester.pumpTimes();
      await scrollTo(tester, find.byKey(AppKeys.programCalendarRow));
      await tester.tapByKey(AppKeys.programCalendarRow);
      await tester.pumpTimes();
      // a phone's width, once over the page: the Workout tab's header under
      // the test font overflows a phone by itself
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpTimes();

      final remove = tester.getRect(find.byKey(AppKeys.programCalendarRemove));
      final save = tester.getRect(find.byKey(AppKeys.programCalendarSave));
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      expect(save.center.dy, closeTo(cancel.center.dy, 1), reason: 'Cancel and Save on one line');
      expect(remove.bottom, lessThanOrEqualTo(cancel.top), reason: 'Remove above them');
      expect(find.text('Remove from calendar'), findsOneWidget);
    });

    testWidgets('left out of Programs, its events go and the setting stays', (tester) async {
      final calendar = _Calendar();
      await openPage(tester, calendar: calendar);
      final context = tester.element(find.byType(Scaffold).last);
      final programs = Programs.of(context);
      await programs.update(programs.lookup('p1')!.copyWith(days: {1, 2, 3, 4, 5, 6, 7}));
      await ProgramCalendars.of(context).set('p1', (calendarId: 'c1', calendar: 'Home', time: 18 * 60));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpTimes();
      expect(calendar.events, isNotEmpty);
      expect(calendar.events.values.first.$2.time, 18 * 60);

      final preferences = Preferences.of(context)..setOption(.programsCalendar, on: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpTimes();

      expect(calendar.events, isEmpty);
      expect(ProgramCalendars.of(context).settingOf('p1'), isNotNull);
      expect(find.byKey(AppKeys.programCalendarRow), findsNothing);
      // an add-on, not a part: leaving it out leaves Programs on
      expect(preferences.isOn(.programs), isTrue);
    });

    group('its links', () {
      Future<HeartRouter> follow(WidgetTester tester, String link) async {
        answer(.on);
        withProgram();
        await openWorkoutTab(tester);
        final router = HeartRouter.of(tester.element(find.byType(MaterialApp)));
        router.config.go(link);
        // the link's bounded wait for the active workout, which a widget
        // test's startup never resolves
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpTimes();
        return router;
      }

      String location(HeartRouter router) => router.config.routerDelegate.currentConfiguration.uri.path;

      testWidgets('one still ahead starts its session', (tester) async {
        when(db.getProgramWorkouts(userId, 'p1')).thenAnswer((_) async => <Workout>[]);
        await follow(tester, '/workout/programs/p1/sessions/t2?week=1');

        final context = tester.element(find.byType(MaterialApp));
        expect(Workouts.of(context).activeWorkout?.name, 'Pull');
      });

      testWidgets('one set aside opens its skip in History, and starts nothing', (tester) async {
        final skip = TrainingSkip(id: 'k1', at: DateTime.utc(2026, 10, 6, 8), templateId: 't1', programId: 'p1');
        when(db.getSkips(userId)).thenAnswer((_) async => [skip]);
        when(api.getSkips()).thenAnswer((_) async => [skip]);
        when(db.getProgramWorkouts(userId, 'p1')).thenAnswer((_) async => <Workout>[]);
        final router = await follow(tester, '/workout/programs/p1/sessions/t1?week=1');

        expect(location(router), '/history/skips/k1');
        expect(find.byKey(AppKeys.skipPage), findsOneWidget);
        expect(Workouts.of(tester.element(find.byType(MaterialApp))).activeWorkout, isNull);
      });

      testWidgets('a skip whose program was deleted still opens, with no way on to it', (tester) async {
        final skip = TrainingSkip(id: 'k2', at: DateTime.utc(2026, 10, 6, 8), templateId: 't1');
        when(db.getSkips(userId)).thenAnswer((_) async => [skip]);
        when(api.getSkips()).thenAnswer((_) async => [skip]);
        when(db.getProgramWorkouts(userId, 'p1')).thenAnswer((_) async => <Workout>[]);
        await follow(tester, '/history/skips/k2');

        expect(find.byKey(AppKeys.skipPage), findsOneWidget);
        expect(find.byKey(AppKeys.skipOpenProgram), findsNothing);
      });

      testWidgets('a session no longer in the program opens the program', (tester) async {
        when(db.getProgramWorkouts(userId, 'p1')).thenAnswer((_) async => <Workout>[]);
        final router = await follow(tester, '/workout/programs/p1/sessions/gone?week=1');

        expect(location(router), '/workout/programs/p1');
      });
    });
  });

  group('what the program goes easy on (#355)', () {
    // the go-easy map (#396), cut to two areas
    final map = jsonEncode({
      'version': 1,
      'areas': {
        for (final (key, name) in [('lower_back', 'Lower back'), ('knee', 'Knee')])
          key: {
            'name': {'en': name},
            'easierOn': {'en': 'Easier on your ${name.toLowerCase()}'},
            'easier': [
              {
                'category': ['Barbell'],
              },
            ],
          },
      },
    });

    Future<void> openPage(WidgetTester tester, {Set<String> listed = const {}, bool published = true}) async {
      answer(.on);
      withProgram();
      when(cdn.getGoEasy(etag: anyNamed('etag'))).thenAnswer(
        (_) async => switch (published) {
          true => (body: map, etag: null),
          false => throw Exception('403'),
        },
      );
      when(db.getContent(any)).thenAnswer((_) async => null);
      when(db.storeContent(any, body: anyNamed('body'), etag: anyNamed('etag'))).thenAnswer((_) async {});
      when(db.getGoEasy(any)).thenAnswer((_) async => listed);
      await openWorkoutTab(tester);
      await GoEasy.of(tester.element(find.byType(MaterialApp))).ensure();
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();
    }

    testWidgets('the page names it, and a choice is the program\'s, synced with it', (tester) async {
      await openPage(tester);
      await scrollTo(tester, find.byKey(AppKeys.programConstraint));
      expect(find.text('Nothing in particular'), findsOneWidget);

      await tester.tapByKey(AppKeys.programConstraint);
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.programConstraintChoice('lower_back'));
      await tester.pumpTimes();

      final sent = verify(api.editProgram(captureAny)).captured.last as Program;
      expect(sent.constraint, 'lower_back');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpTimes();
      expect(find.text('Lower back'), findsOneWidget);

      await tester.tapByKey(AppKeys.programConstraint);
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.programConstraintChoice(null));
      await tester.pumpTimes();
      expect((verify(api.editProgram(captureAny)).captured.last as Program).constraint, isNull);
    });

    testWidgets("the user's own list never becomes the program's, nor moves with it", (tester) async {
      await openPage(tester, listed: {'knee'});
      await scrollTo(tester, find.byKey(AppKeys.programConstraint));
      expect(
        find.text('Nothing in particular'),
        findsOneWidget,
        reason: 'the list on this phone suggests nothing here',
      );

      await tester.tapByKey(AppKeys.programConstraint);
      await tester.pumpTimes();
      final knee = tester.widget<ChoiceChip>(find.byKey(AppKeys.programConstraintChoice('knee')));
      expect(knee.selected, isFalse);
      await tester.tapByKey(AppKeys.programConstraintChoice('lower_back'));
      await tester.pumpTimes();

      final sent = verify(api.editProgram(captureAny)).captured.last as Program;
      expect(jsonEncode(sent.toMap()), isNot(contains('knee')));
      verifyNever(db.storeGoEasy(any, any));
    });

    testWidgets('no map published, no row: there is nothing to name it by', (tester) async {
      await openPage(tester, published: false);
      expect(find.byKey(AppKeys.programConstraint), findsNothing);
    });
  });
}

/// The device's calendars, as far as a test needs them: one to pick, and the
/// events written to it, by id.
class _Calendar implements DeviceCalendar {
  final events = <String, (String, CalendarEventDraft)>{};
  var listed = 0;
  var _next = 0;

  @override
  Future<List<CalendarChoice>> calendars() async {
    listed++;
    return [
      (id: 'c1', title: 'Home', account: 'iCloud', color: const Color(0xFF3366FF), writable: true),
      (
        id: 'c2',
        title: 'US Holidays',
        account: 'Subscribed Calendars',
        color: const Color(0xFF33CC66),
        writable: false,
      ),
    ];
  }

  @override
  Future<String> create(String calendarId, CalendarEventDraft event) async {
    final id = 'e${_next++}';
    events[id] = (calendarId, event);
    return id;
  }

  @override
  Future<void> delete(String eventId) async => events.remove(eventId);
}
