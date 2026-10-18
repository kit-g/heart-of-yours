// Heart's ready-made programs (#352, #162): the way in from the Workout tab,
// the library, a program's page with its research, and starting one. Driven
// through the real app, as program_screens_test.dart is.
import 'dart:io';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  const userId = 'u1';
  // three programs of the real file, rendered by heart-api and trimmed
  final file = File('shared/heart_state/test/fixtures/programs.json').readAsStringSync();

  /// Every exercise the fixture names, as the catalog would hold it: a session
  /// key or two come along, which nothing looks up.
  final catalog = [
    for (final key in RegExp(
      r'"key": "([a-z0-9-]+)"|"([a-z0-9]+(?:-[a-z0-9]+)+)"',
    ).allMatches(file).map((match) => match.group(1) ?? match.group(2)!).toSet())
      Exercise.fromJson({
        'id': 'id-$key',
        'key': key,
        'own': false,
        'name': key,
        'category': 'Barbell',
        'target': 'Chest',
        'archived': false,
        'validated': false,
      }),
  ];

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  void answer(FeatureAnswer answer) {
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-programs': answer.name});
  }

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, catalog));

    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    when(cdn.getProgramLibrary(etag: anyNamed('etag'))).thenAnswer((_) async => (body: file, etag: '"v1"'));
    when(db.getContent(any)).thenAnswer((_) async => null);
    when(db.storeContent(any, body: anyNamed('body'), etag: anyNamed('etag'))).thenAnswer((_) async {});

    when(db.getTemplates(any)).thenAnswer((_) async => <Template>[]);
    when(api.getTemplates()).thenAnswer((_) async => null);
    when(db.getTemplateFolders(userId)).thenAnswer((_) async => <TemplateFolder>[]);
    when(api.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => <TemplateFolder>[]);
    when(db.storeTemplateFolders(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(db.storeTemplates(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(api.createFolder(userId: anyNamed('userId'), folder: anyNamed('folder'))).thenAnswer(
      (i) async => TemplateFolder.fromJson({...(i.namedArguments[#folder] as TemplateFolder).toMap(), 'id': 'f1'}),
    );

    when(db.getPrograms(userId)).thenAnswer((_) async => <Program>[]);
    when(db.getProgramActions(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramBases(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramMarks(userId, any)).thenAnswer((_) async => []);
    when(db.storePrograms(any, any)).thenAnswer((_) async {});
    when(db.storeProgram(any, any)).thenAnswer((_) async {});
    when(db.storeProgramActions(any, any)).thenAnswer((_) async {});
    when(db.storeProgramBases(any, any)).thenAnswer((_) async {});
    when(api.getPrograms()).thenAnswer((_) async => <Program>[]);
    when(api.getProgramActions(any)).thenAnswer((_) async => []);
    when(api.getProgramBases(any)).thenAnswer((_) async => []);
    when(api.replayProgram(any, sessions: anyNamed('sessions'))).thenAnswer(
      (i) async => (row: i.positionalArguments.single as Program, created: true),
    );
  });

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
    await Exercises.of(context).init();
    final templates = Templates.of(context);
    await templates.init();
    templates.notifyListeners();
    await Programs.of(context).init();
    await ProgramLibrary.of(context).ensure();
    await tester.pumpTimes();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpTimes();
  }

  Future<void> openLibrary(WidgetTester tester) async {
    await openWorkoutTab(tester);
    await tester.tapByKey(AppKeys.libraryEntry);
    await tester.pumpTimes();
  }

  Future<void> openFirstSteps(WidgetTester tester) async {
    await openLibrary(tester);
    await tester.tapByKey(AppKeys.libraryProgram('first_steps'));
    await tester.pumpTimes();
  }

  group('the way in', () {
    testWidgets('on, with no program and no folder, the library is what there is to start from', (tester) async {
      answer(.on);
      await openWorkoutTab(tester);

      expect(find.byKey(AppKeys.libraryEntry), findsOneWidget);
      expect(find.text('Any folder of templates can become one.'), findsNothing);
    });

    testWidgets('not published yet, there is no library and nothing in its place', (tester) async {
      answer(.on);
      when(cdn.getProgramLibrary(etag: anyNamed('etag'))).thenAnswer((_) async => throw Exception('403'));
      await openWorkoutTab(tester);

      expect(find.byKey(AppKeys.libraryEntry), findsNothing);
      expect(find.text('Programs'), findsNothing);
    });

    testWidgets('never answered, the library is there: Programs is on by default', (tester) async {
      answer(.unasked);
      await openWorkoutTab(tester);
      await scrollTo(tester, find.byKey(AppKeys.libraryEntry));

      expect(find.byKey(AppKeys.libraryEntry), findsOneWidget);
    });

    testWidgets('off, there is no way in and no offer', (tester) async {
      answer(.off);
      await openWorkoutTab(tester);

      expect(find.byKey(AppKeys.libraryEntry), findsNothing);
    });
  });

  group('the library', () {
    testWidgets('groups programs by who they are for, and filters by what they need', (tester) async {
      answer(.on);
      await openLibrary(tester);

      expect(find.text('Ready-made programs'), findsOneWidget);
      expect(find.text('Starting out'), findsOneWidget);
      expect(find.text('Getting stronger'), findsOneWidget);
      expect(find.byKey(AppKeys.libraryProgram('first_steps')), findsOneWidget);
      expect(find.byKey(AppKeys.libraryProgram('strength_waves')), findsOneWidget);
      expect(find.text('2× a week · About 30 min · 8 weeks'), findsOneWidget);

      await tester.tap(find.text('Gym'));
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.libraryProgram('first_steps')), findsNothing);
      expect(find.byKey(AppKeys.libraryProgram('strength_waves')), findsOneWidget);
      expect(find.text('Starting out'), findsNothing);
    });
  });

  group("a program's page", () {
    testWidgets('shows the plan with its research beside it and the safety notes once', (tester) async {
      answer(.on);
      await openFirstSteps(tester);

      expect(find.text('First steps'), findsOneWidget);
      await scrollTo(tester, find.text('Before you start'));
      expect(find.text('Before you start'), findsOneWidget);
      expect(find.textContaining('Stop and rest if you feel chest pain'), findsOneWidget);
      await scrollTo(tester, find.text('Who it\'s for'));
      expect(find.text('Who it\'s for'), findsOneWidget);
      await scrollTo(tester, find.textContaining('Climbing to harder versions of an exercise'));
      // a claim about the rule, under how it grows, with its source beside it
      expect(find.textContaining('Climbing to harder versions of an exercise'), findsOneWidget);
      expect(find.text('Kotarsky et al., 2018'), findsWidgets);

      await scrollTo(tester, find.text('Sources'));
      expect(find.byKey(AppKeys.librarySource('kotarsky_2018')), findsOneWidget);
      // nothing is copied by looking
      verifyNever(db.storeProgram(any, any));
    });

    testWidgets('a quote with one source is one link, the whole of it', (tester) async {
      answer(.on);
      await openFirstSteps(tester);
      final semantics = tester.ensureSemantics();
      final quote = find.textContaining('Climbing to harder versions of an exercise');
      await scrollTo(tester, quote);

      // the quote's words and its source are one node: a link that taps
      final node = tester.getSemantics(quote);
      expect(node.flagsCollection.isLink, isTrue);
      expect(node.getSemanticsData().hasAction(.tap), isTrue);
      expect(node.label, contains('Kotarsky et al., 2018'));
      // and the source beside it is not a second control
      expect(find.ancestor(of: find.text('Kotarsky et al., 2018').first, matching: find.byType(Tooltip)), findsNothing);
      semantics.dispose();
    });

    testWidgets('starting it makes the program and its sessions the user\'s own, filed in a folder of its name', (
      tester,
    ) async {
      answer(.on);
      await openFirstSteps(tester);
      await tester.tapByKey(AppKeys.libraryStart);
      await tester.pumpTimes();
      // which days suit: Monday and Thursday, from the user's first day
      expect(find.byKey(AppKeys.libraryStartDays), findsOneWidget);
      for (final day in ['Monday', 'Thursday']) {
        await tester.tap(find.bySemanticsLabel(day));
      }
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.libraryStartDaysStart);
      await tester.pumpTimes();

      final folder = verify(api.createFolder(userId: userId, folder: captureAnyNamed('folder'))).captured.single;
      expect((folder as TemplateFolder).name, 'First steps');
      final program = verify(db.storeProgram(captureAny, userId)).captured.last as Program;
      expect(program.source, 'first_steps');
      expect(program.days, {DateTime.monday, DateTime.thursday});
      expect(program.rules['id-wall-push-up'], isA<Ladder>());
      final sessions = verify(db.storeTemplates(captureAny, userId: userId)).captured.last as Iterable<Template>;
      expect(sessions, hasLength(2));
      expect(sessions.map((session) => session.folderId).toSet(), {'f1'});
      expect(sessions.map((session) => session.programId).toSet(), {program.id});

      // on the program's own page, which leads back to the research
      await scrollTo(tester, find.byKey(AppKeys.programAbout));
      expect(find.byKey(AppKeys.programAbout), findsOneWidget);

      // the research stacks over the program, so Back is the program again
      await tester.tapByKey(AppKeys.programAbout);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.libraryOpenYours), findsOneWidget);
      await tester.pageBack();
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.programAbout), findsOneWidget);
      // and Back from the program is the library page it was started from
      await tester.pageBack();
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.libraryOpenYours), findsOneWidget);
    });

    testWidgets('waving the days away starts nothing', (tester) async {
      answer(.on);
      await openFirstSteps(tester);
      await tester.tapByKey(AppKeys.libraryStart);
      await tester.pumpTimes();
      // Start waits for a day; Skip would start with none
      expect(
        tester.widget<PrimaryButton>(find.byKey(AppKeys.libraryStartDaysStart)).onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpTimes();

      verifyNever(db.storeProgram(any, any));
      expect(find.byKey(AppKeys.libraryStart), findsOneWidget);
    });

    testWidgets('a start that fails takes its folder back, so nothing changed is true', (tester) async {
      answer(.on);
      when(db.storeProgram(any, any)).thenThrow(StateError('disk full'));
      when(api.deleteFolder(userId: anyNamed('userId'), folderId: anyNamed('folderId'))).thenAnswer((_) async {});
      await openFirstSteps(tester);
      await tester.tapByKey(AppKeys.libraryStart);
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.libraryStartDaysSkip);
      await tester.pumpTimes();

      verify(api.createFolder(userId: userId, folder: anyNamed('folder'))).called(1);
      verify(api.deleteFolder(userId: userId, folderId: 'f1')).called(1);
      expect(Templates.of(tester.element(find.byType(MaterialApp))).folders, isEmpty);
    });

    testWidgets('a program whose sessions do not fit says why, in place of the button', (tester) async {
      answer(.on);
      when(db.getTemplates(userId)).thenAnswer(
        (_) async => [
          for (var i = 0; i < 3; i++) Template.empty(id: 't$i', order: i)..name = 'Mine $i',
        ],
      );
      await openLibrary(tester);
      await tester.tapByKey(AppKeys.libraryProgram('strength_waves'));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.libraryStart), findsNothing);
      expect(find.text('It needs room for 3 more templates.'), findsOneWidget);
    });
  });

  group('things to go easy on (#396)', () {
    final map = File('shared/heart_state/test/fixtures/go_easy.json').readAsStringSync();

    /// The catalog, with movement data where the marks need it: a step-up
    /// is a lunge, harder on a knee; a bridge is kinder to one.
    void withMovement() {
      final moved = [
        for (final exercise in catalog)
          switch (exercise.id) {
            'id-step-up-bodyweight' || 'id-glute-bridge' => Exercise.fromJson({
              ...exercise.toMap(),
              'id': exercise.id,
              'key': exercise.id.substring(3),
              'name': exercise.name,
              'own': false,
              'category': 'Reps Only',
              'target': 'Legs',
              'archived': false,
              'validated': false,
              'movement': {
                'groups': [exercise.id == 'id-glute-bridge' ? 'hip_extension_bridge' : 'lunge_split'],
                'axialLoad': 'none',
                'stability': 'free',
                'unilateral': false,
                'impact': 'none',
                'skill': 'low',
              },
            }),
            _ => exercise,
          },
      ];
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, moved));
    }

    Future<void> openWith(WidgetTester tester, {Set<String> listed = const {}, bool published = true}) async {
      answer(.on);
      withMovement();
      when(cdn.getGoEasy(etag: anyNamed('etag'))).thenAnswer(
        (_) async => switch (published) {
          true => (body: map, etag: '"g1"'),
          false => throw Exception('403'),
        },
      );
      when(db.getGoEasy(userId)).thenAnswer((_) async => listed);
      when(db.storeGoEasy(any, any)).thenAnswer((_) async {});
      await openFirstSteps(tester);
      final context = tester.element(find.byType(MaterialApp));
      await GoEasy.of(context).ensure();
      await tester.pumpTimes();
    }

    testWidgets('not published yet, nothing is asked and nothing marked', (tester) async {
      await openWith(tester, listed: {'knee'}, published: false);
      expect(find.byKey(AppKeys.goEasyRow), findsNothing);
      expect(find.byIcon(Icons.spa_outlined), findsNothing);
    });

    testWidgets('asked on the page, after the sessions, kept on this phone only', (tester) async {
      await openWith(tester);
      // the program first, then what to be careful with in it: by the time
      // the sessions begin, the row is still below
      final row = find.byKey(AppKeys.goEasyRow);
      await scrollTo(tester, find.text('Sessions'));
      final sessions = tester.getTopLeft(find.text('Sessions')).dy;
      expect(row.evaluate().isEmpty || tester.getTopLeft(row).dy > sessions, isTrue);
      await scrollTo(tester, row);
      expect(find.descendant(of: row, matching: find.text('Nothing yet')), findsOneWidget);

      await tester.tapByKey(AppKeys.goEasyRow);
      await tester.pumpTimes();
      expect(find.text('Things to go easy on'), findsWidgets);
      await tester.tapByKey(AppKeys.goEasy('knee'));
      await tester.pumpTimes();

      verify(db.storeGoEasy(userId, {'knee'})).called(1);
    });

    testWidgets('an exercise harder on the list is marked, and the mark offers kinder swaps', (tester) async {
      await openWith(tester, listed: {'knee'});

      final semantics = tester.ensureSemantics();
      await scrollTo(tester, find.text('step-up-bodyweight'));
      final mark = find.byType(GoEasyMarker);
      expect(mark, findsOneWidget);
      expect(find.bySemanticsLabel('Harder on what you go easy on: Knee'), findsOneWidget);
      semantics.dispose();

      await tester.tap(mark);
      await tester.pumpTimes();
      expect(find.text('Easier on your knee'), findsOneWidget);
      // a bridge works the legs too, and the map calls it kinder to a knee
      expect(find.text('glute-bridge'), findsWidgets);
      expect(find.text("Suggestions only: a session's exercises change in its template."), findsOneWidget);
    });
  });
}
