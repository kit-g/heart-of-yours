// Programs on the Workout tab (#345, #347, #348): the ask, the without state,
// the band, the program page and making one from a folder. The tab's pieces
// are private to the `workout.dart` library, so these drive the real app
// through the router, as `templates_test.dart` does.
import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
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
  });

  /// Signs in and lands on the Workout tab with templates and programs read.
  /// Both notifiers are initialised directly: the app's own startup chain runs
  /// in the root zone, which a widget test never pumps (see templates_test).
  Future<void> openWorkoutTab(WidgetTester tester) async {
    await const TestAppHarness().pumpHeartApp(
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

  group('the ask (#345)', () {
    testWidgets('a folder to make one from earns the offer, under the examples', (tester) async {
      answer(.unasked);
      await openWorkoutTab(tester);
      await scrollTo(tester, find.byKey(AppKeys.programsOffer));

      expect(find.byKey(AppKeys.programsOffer), findsOneWidget);
      // the tab above it is the 1.13 tab: no Programs header yet
      expect(find.byKey(AppKeys.programsFromFolder), findsNothing);
    });

    testWidgets('yes brings the whole feature: the header and the way in', (tester) async {
      answer(.unasked);
      await openWorkoutTab(tester);
      await scrollTo(tester, find.byKey(AppKeys.programsAccept));
      await tester.tapByKey(AppKeys.programsAccept);
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.programsOffer), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(AppKeys.programsFromFolder),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(AppKeys.programsFromFolder), findsOneWidget);
    });

    testWidgets('no earns one notice, and nothing else', (tester) async {
      answer(.unasked);
      await openWorkoutTab(tester);
      await scrollTo(tester, find.byKey(AppKeys.programsDecline));
      await tester.tapByKey(AppKeys.programsDecline);
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
      expect(find.byKey(AppKeys.programsFromFolder), findsNothing);
    });

    testWidgets('nothing to make a program of: no offer', (tester) async {
      answer(.unasked);
      when(db.getTemplateFolders(userId)).thenAnswer((_) async => <TemplateFolder>[]);
      when(api.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => <TemplateFolder>[]);
      when(db.getTemplates(userId)).thenAnswer((_) async => <Template>[]);
      await openWorkoutTab(tester);

      expect(find.byKey(AppKeys.programsOffer), findsNothing);
    });

    testWidgets('off, the tab and the folder menu are as before programs', (tester) async {
      answer(.off);
      withProgram();
      await openWorkoutTab(tester);

      expect(find.byKey(AppKeys.programBand('p1')), findsNothing);
      expect(find.byKey(AppKeys.programsFromFolder), findsNothing);
      expect(find.byKey(AppKeys.programsOffer), findsNothing);

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
      expect(find.descendant(of: band, matching: find.text('Week 1 of 8')), findsOneWidget);
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

  group('the program page (#347)', () {
    Future<void> openPage(WidgetTester tester) async {
      answer(.on);
      withProgram();
      await openWorkoutTab(tester);
      await tester.tap(find.descendant(of: find.byKey(AppKeys.programBand('p1')), matching: find.text('Split')));
      await tester.pumpTimes();
    }

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
}
