import 'dart:async';

import 'package:clock/clock.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// History's muscle-group filter (#610), in the app: the list and the
/// calendar narrowed to the workouts that trained the groups picked, over the
/// whole history.
void main() {
  final bench = Exercise.fromJson({
    'id': 'bench',
    'name': 'Bench Press',
    'category': 'Barbell',
    'target': 'Chest',
    'muscles': {
      'primary': {
        'ids': <String>[],
        'groups': ['chest'],
      },
      'secondary': {
        'ids': <String>[],
        'groups': ['arms'],
      },
    },
  });
  final squat = Exercise.fromJson({
    'id': 'squat',
    'name': 'Squat',
    'category': 'Barbell',
    'target': 'Legs',
    'muscles': {
      'primary': {
        'ids': <String>[],
        'groups': ['legs'],
      },
    },
  });
  // one of the user's own, tagged by nobody: its target places it
  final own = Exercise.fromJson({'id': 'own', 'name': 'Muffin Row', 'category': 'Machine', 'target': 'Back'});

  Workout finished(String name, Exercise exercise, DateTime start) {
    final workout = Workout(name: name)..start = start;
    workout.add(exercise);
    workout.completeAllSets();
    return workout..finish(start.add(const Duration(hours: 1)));
  }

  // A fixed day, read through package:clock as the calendar reads it: no
  // fixture's day is "today" by accident, whatever day the suite runs on.
  final now = DateTime(2026, 11, 20, 12);
  void testFilter(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) => withClock(Clock.fixed(now), () => body(tester)));
  }

  final chestDay = finished('Chest day', bench, DateTime(2026, 11, 5, 9));
  final legDay = finished('Leg day', squat, DateTime(2026, 11, 5, 18));
  final backDay = finished('Back day', own, DateTime(2026, 10, 3, 9));

  Future<MockApi> pumpApp(
    WidgetTester tester, {
    required List<Workout> history,
    Size size = const Size(390, 844),
    bool account = false,
    void Function(MockLocalDatabase db, MockApi api)? stub,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => history);
    stub?.call(db, api);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, squat]));
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(
        mockUser: switch (account) {
          // an account pages its history from the server
          true => MockUser(uid: 'u1', email: 'muffin@test'),
          false => MockUser(uid: 'u1', isAnonymous: true),
        },
        signedIn: true,
      ),
      settle: false,
    );
    await tester.tapByKey(AppKeys.historyStack);
    await tester.pumpTimes();
    return api;
  }

  Future<void> pick(WidgetTester tester, MuscleGroupKey group) async {
    await tester.tapByKey(AppKeys.historyFilter);
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.historyFilterGroup(group.value));
    await tester.pumpTimes();
  }

  Iterable<String?> cards(WidgetTester tester) {
    return tester.widgetList<WorkoutItem>(find.byType(WorkoutItem)).map((item) => item.workout.name);
  }

  testFilter('the list shows the workouts that trained any group picked (#610)', (tester) async {
    await pumpApp(tester, history: [chestDay, legDay, backDay]);
    expect(cards(tester), hasLength(3));
    expect(find.byKey(AppKeys.historyFilterChips), findsNothing);

    await pick(tester, .legs);
    expect(cards(tester), ['Leg day']);
    expect(find.byKey(AppKeys.historyFilterChips), findsOneWidget);
    // a month with nothing in the filter has no heading either
    expect(find.text('OCTOBER 2026'), findsNothing);

    // the user's own row, untagged, counts by its target
    await pick(tester, .back);
    expect(cards(tester), ['Leg day', 'Back day']);

    // the chip's × takes its group out
    await tester.tap(find.descendant(of: find.widgetWithText(Chip, 'Legs'), matching: find.byTooltip('Remove filter')));
    await tester.pumpTimes();
    expect(cards(tester), ['Back day']);
    expect(HistoryFilter.of(tester.element(find.byType(HistoryPage))).groups, {MuscleGroupKey.back});
    expect(tester.takeException(), isNull);
  });

  testFilter('secondary muscles do not count: a bench session is no arm day (#610)', (tester) async {
    await pumpApp(tester, history: [chestDay, legDay]);
    final context = tester.element(find.byType(HistoryPage));
    HistoryFilter.of(context).toggle(.arms);
    await tester.pumpTimes();

    expect(cards(tester), isEmpty);
    expect(find.byKey(AppKeys.historyFilterEmpty), findsOneWidget);

    await tester.tapByKey(AppKeys.historyFilterClear);
    await tester.pumpTimes();
    expect(cards(tester), hasLength(2));
    expect(HistoryFilter.of(context).isOn, isFalse);
    expect(tester.takeException(), isNull);
  });

  testFilter('with the whole history here, a group none of it trained is greyed (#610)', (tester) async {
    await pumpApp(tester, history: [chestDay, legDay]);
    // greyed only once the library's tags are read
    await Exercises.of(tester.element(find.byType(HistoryPage))).init();
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.historyFilter);
    await tester.pumpTimes();

    bool enabled(MuscleGroupKey group) {
      return tester
          .widget<CheckedPopupMenuItem<MuscleGroupKey>>(find.byKey(AppKeys.historyFilterGroup(group.value)))
          .enabled;
    }

    expect(enabled(.chest), isTrue);
    expect(enabled(.legs), isTrue);
    expect(enabled(.arms), isFalse);
    expect(enabled(.neck), isFalse);
  });

  testFilter('the calendar marks only the days the filter lets through (#610)', (tester) async {
    final semantics = tester.ensureSemantics();
    final other = finished('Chest again', bench, DateTime(2026, 11, 6, 9));
    final today = finished('Chest today', bench, DateTime(2026, 11, 20, 8));
    await pumpApp(tester, history: [chestDay, legDay, other, today], size: const Size(1194, 834));
    final context = tester.element(find.byType(HistoryPage));
    Preferences.of(context).setHistoryView(.calendar);
    HistoryFilter.of(context).toggle(.legs);
    await tester.pumpTimes();

    String label(DateTime day) => DateFormat.yMMMMEEEEd('en').format(day);
    Finder day(String label) =>
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

    // the 5th holds two, one of them legs: one mark, and it opens that one
    expect(day('${label(chestDay.start)}, edit workout'), findsOneWidget);
    // the 6th trained only chest: plain, and it does nothing — it is not empty
    expect(tester.widget<Semantics>(day(label(other.start))).properties.onTap, isNull);
    // nor does today, for the same reason: no "start", no "add another"
    expect(tester.widget<Semantics>(day('${label(today.start)}, today')).properties.onTap, isNull);
    expect(find.byKey(AppKeys.historyFilterChips), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  // what the server's pages say there is, beyond what the device holds
  final recent = [
    for (final hour in List.generate(12, (index) => index + 1))
      finished('Chest $hour', bench, DateTime(2026, 11, 1, hour)),
  ];
  final older = finished('Old leg day', squat, DateTime(2025, 3, 4, 9));

  testFilter('a device holding the whole history filters it without paging (#610)', (tester) async {
    final api = await pumpApp(
      tester,
      history: recent,
      account: true,
      // the server's first page says there is more, as it does on every
      // launch; the mark says the device already has it all
      stub: (_, api) => when(
        api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since')),
      ).thenAnswer((_) async => Page(items: recent.reversed.toList(), hasMore: true)),
    );
    final context = tester.element(find.byType(HistoryPage));
    await Backfill.of(context).run('u1');
    expect(Workouts.of(context).hasMoreHistory, isTrue);

    HistoryFilter.of(context).toggle(.legs);
    await tester.pumpTimes();

    expect(find.byKey(AppKeys.historyFilterEmpty), findsOneWidget);
    verifyNever(
      api.getWorkouts(
        any,
        pageSize: anyNamed('pageSize'),
        since: argThat(isNotNull, named: 'since'),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testFilter('while the backfill is still bringing history down, the filter waits for it (#610)', (tester) async {
    final page = Completer<Iterable<Workout>>();
    await pumpApp(
      tester,
      history: recent,
      account: true,
      stub: (db, api) {
        // a device short of the account, with the rest still to come
        when(db.isHistoryBackfilled(any)).thenAnswer((_) async => false);
        when(db.mirrorSummary(any)).thenAnswer(
          (_) async => const AccountSummary(
            collections: {ExportableCollection.workouts: CollectionSummary(count: 12)},
          ),
        );
        when(api.getAccountSummary()).thenAnswer(
          (_) async => const AccountSummary(
            collections: {ExportableCollection.workouts: CollectionSummary(count: 13)},
          ),
        );
        when(api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since'))).thenAnswer(
          (invocation) => switch (invocation.namedArguments[#since]) {
            null => Future.value(Page(items: recent.reversed.toList(), hasMore: true)),
            _ => page.future,
          },
        );
      },
    );
    final context = tester.element(find.byType(HistoryPage));
    unawaited(Backfill.of(context).run('u1'));
    HistoryFilter.of(context).toggle(.legs);
    await tester.pumpTimes();

    // nothing in what is here, and more on its way: no "nothing matches" yet
    expect(find.text('Looking through older workouts…'), findsOneWidget);
    expect(find.byKey(AppKeys.historyFilterEmpty), findsNothing);

    page.complete(Page(items: [older], hasMore: false));
    await tester.pumpTimes();

    expect(cards(tester), ['Old leg day']);
    expect(tester.takeException(), isNull);
  });

  group('by template and by date (#740)', () {
    Template template(String id, int order, String name, {String? programId}) {
      final draft = Template.empty(id: id, order: order)
        ..name = name
        ..add(bench);
      return Template.fromJson({...draft.toMap(), 'programId': ?programId});
    }

    Program program(String id, String name, List<String> sessions, {DateTime? began}) {
      return Program(id: id, name: name, perWeek: 3, weeks: 8, sessions: sessions, createdAt: began ?? now);
    }

    Workout of(String? templateId, String name, DateTime start, [Exercise? exercise]) {
      return Workout.fromJson({...finished(name, exercise ?? bench, start).toMap(), 'templateId': ?templateId});
    }

    final push = of('push', 'Push one', DateTime(2026, 11, 5, 9));
    final pushLegs = of('push', 'Push and legs', DateTime(2026, 11, 6, 9), squat);
    final pull = of('pull', 'Pull one', DateTime(2026, 10, 3, 9));
    final loose = of(null, 'Push', DateTime(2026, 11, 7, 9));
    final gone = of('gone', 'Gone', DateTime(2026, 11, 8, 9));

    void Function(MockLocalDatabase, MockApi) stored(List<Template> templates, {List<Program> programs = const []}) {
      return (db, api) {
        SharedPreferences.setMockInitialValues({
          ...pastOnboarding(),
          'feature-programs': programs.isEmpty ? 'off' : 'on',
        });
        // the samples are the rows of no user
        when(db.getTemplates(any)).thenAnswer((i) async => i.positionalArguments.single == null ? [] : templates);
        when(db.getPrograms(any)).thenAnswer((_) async => programs);
        when(db.getProgramActions(any, programId: anyNamed('programId'))).thenAnswer((_) async => []);
        when(db.getProgramBases(any, programId: anyNamed('programId'))).thenAnswer((_) async => []);
        when(db.getProgramMarks(any, any)).thenAnswer((_) async => []);
      };
    }

    /// The app with its templates and programs read, which a test's startup
    /// doesn't wait for.
    Future<void> launch(
      WidgetTester tester, {
      required List<Workout> history,
      required void Function(MockLocalDatabase, MockApi) stub,
      Size size = const Size(390, 844),
    }) async {
      await pumpApp(tester, history: history, size: size, stub: stub);
      final context = tester.element(find.byType(HistoryPage));
      final (templates, programs) = (Templates.of(context), Programs.of(context));
      await templates.init();
      await programs.init();
      await tester.pumpTimes();
    }

    final own = [template('push', 0, 'Push'), template('pull', 1, 'Pull'), template('rest', 2, 'Never done')];

    Future<void> axis(WidgetTester tester, String name) async {
      await tester.tapByKey(AppKeys.historyFilter);
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.historyFilterAxis(name));
      await tester.pumpTimes();
    }

    Future<void> pickTemplate(WidgetTester tester, String id) async {
      await axis(tester, 'templates');
      await tester.tapByKey(AppKeys.historyFilterTemplate(id));
      await tester.pumpTimes();
    }

    Future<void> takeOut(WidgetTester tester, Key chip) async {
      await tester.tap(find.descendant(of: find.byKey(chip), matching: find.byTooltip('Remove filter')));
      await tester.pumpTimes();
    }

    HistoryFilter filterOf(WidgetTester tester) => HistoryFilter.of(tester.element(find.byType(HistoryPage)));

    testFilter('the list shows the workouts of any template picked, and no one guessed by name', (tester) async {
      await launch(tester, history: [push, pull, loose, gone], stub: stored(own));

      await pickTemplate(tester, 'push');
      expect(cards(tester), ['Push one']);
      await pickTemplate(tester, 'pull');
      expect(cards(tester), ['Push one', 'Pull one']);

      await takeOut(tester, AppKeys.historyFilterTemplateChip('push'));
      expect(cards(tester), ['Pull one']);
      expect(tester.takeException(), isNull);
    });

    testFilter('a template nothing was done from is greyed, and a deleted one is not offered', (tester) async {
      await launch(tester, history: [push, gone], stub: stored(own));
      await axis(tester, 'templates');

      bool enabled(String id) {
        return tester.widget<CheckedPopupMenuItem<String>>(find.byKey(AppKeys.historyFilterTemplate(id))).enabled;
      }

      expect(enabled('push'), isTrue);
      expect(enabled('rest'), isFalse);
      expect(find.byKey(AppKeys.historyFilterTemplate('gone')), findsNothing);
    });

    testFilter('one deleted after it was picked is still taken out by its chip', (tester) async {
      await launch(tester, history: [push, gone], stub: stored(own));
      filterOf(tester).toggleTemplate('gone');
      await tester.pumpTimes();

      expect(find.widgetWithText(Chip, 'Deleted template'), findsOneWidget);
      expect(cards(tester), ['Gone']);
      await takeOut(tester, AppKeys.historyFilterTemplateChip('gone'));
      expect(filterOf(tester).isOn, isFalse);
    });

    testFilter('no templates, no way to them', (tester) async {
      await launch(tester, history: [loose], stub: stored(const []));
      await tester.tapByKey(AppKeys.historyFilter);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.historyFilterAxis('templates')), findsNothing);
      expect(find.byKey(AppKeys.historyFilterAxis('from')), findsOneWidget);
    });

    testFilter("sessions are under their program's name, and two runs of one are told apart", (tester) async {
      final sessions = [
        template('push', 0, 'Push'),
        template('a1', 1, 'Day A', programId: 'p1'),
        template('a2', 2, 'Day A', programId: 'p2'),
      ];
      await launch(
        tester,
        history: [
          push,
          of('a1', 'First run', DateTime(2026, 9, 2, 9)),
          of('a2', 'Second run', DateTime(2026, 11, 2, 9)),
        ],
        stub: stored(
          sessions,
          programs: [
            program('p1', 'Split', ['a1'], began: DateTime(2026, 9)),
            program('p2', 'Split', ['a2'], began: DateTime(2026, 11)),
          ],
        ),
      );
      await axis(tester, 'templates');
      expect(find.text('Split · Sep 2026'), findsOneWidget);
      expect(find.text('Split · Nov 2026'), findsOneWidget);

      await tester.tapByKey(AppKeys.historyFilterTemplate('a2'));
      await tester.pumpTimes();
      expect(cards(tester), ['Second run']);
      expect(find.widgetWithText(Chip, 'Day A · Split · Nov 2026'), findsOneWidget);
    });

    testFilter('with Programs off, their sessions are not offered', (tester) async {
      await launch(
        tester,
        history: [push, of('a1', 'Run', DateTime(2026, 9, 2, 9))],
        stub: stored([template('push', 0, 'Push'), template('a1', 1, 'Day A', programId: 'p1')]),
      );
      await axis(tester, 'templates');
      expect(find.byKey(AppKeys.historyFilterTemplate('push')), findsOneWidget);
      expect(find.byKey(AppKeys.historyFilterTemplate('a1')), findsNothing);
    });

    testFilter('a stretch of days, each end picked and taken out by itself', (tester) async {
      await launch(tester, history: [push, pushLegs, pull], stub: stored(own));

      await axis(tester, 'from');
      await tester.tap(find.text('6'));
      await tester.pumpTimes();
      await tester.tap(find.text('OK'));
      await tester.pumpTimes();
      expect(filterOf(tester).from, DateTime(2026, 11, 6));
      expect(cards(tester), ['Push and legs']);
      expect(find.widgetWithText(Chip, 'From Nov 6, 2026'), findsOneWidget);

      // the other end goes no further back than it
      await axis(tester, 'until');
      expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).firstDate, DateTime(2026, 11, 6));
      await tester.tap(find.text('Cancel'));
      await tester.pumpTimes();
      expect(filterOf(tester).until, isNull);

      filterOf(tester)
        ..from = null
        ..until = DateTime(2026, 11, 5);
      await tester.pumpTimes();
      expect(cards(tester), ['Push one', 'Pull one']);
      await takeOut(tester, AppKeys.historyFilterUntilChip);
      expect(cards(tester), hasLength(3));
    });

    testFilter('across axes all of them have to match, and Clear takes them all out', (tester) async {
      await launch(tester, history: [push, pushLegs, pull, legDay], stub: stored(own));
      final filter = filterOf(tester)
        ..toggle(.legs)
        ..toggleTemplate('push');
      await tester.pumpTimes();
      expect(cards(tester), ['Push and legs']);

      filter.until = DateTime(2026, 11, 5);
      await tester.pumpTimes();
      expect(cards(tester), isEmpty);
      expect(find.byType(Chip), findsNWidgets(3));
      await tester.tapByKey(AppKeys.historyFilterClear);
      await tester.pumpTimes();
      expect(filter.isOn, isFalse);
      expect(cards(tester), hasLength(4));
    });

    for (final view in [HistoryView.calendar, HistoryView.month]) {
      testFilter('the ${view.value} view marks only the days that match', (tester) async {
        final semantics = tester.ensureSemantics();
        await launch(
          tester,
          history: [push, pushLegs, loose],
          size: const Size(1194, 834),
          stub: stored(own),
        );
        Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(view);
        filterOf(tester)
          ..toggleTemplate('push')
          ..from = DateTime(2026, 11, 6);
        await tester.pumpTimes();

        String label(DateTime day) => DateFormat.yMMMMEEEEd('en').format(day);
        Finder day(String label) {
          return find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);
        }

        expect(day('${label(pushLegs.start)}, edit workout'), findsOneWidget);
        // trained, and left out: plain, and it does nothing
        expect(tester.widget<Semantics>(day(label(push.start))).properties.onTap, isNull);
        expect(tester.widget<Semantics>(day(label(loose.start))).properties.onTap, isNull);
        expect(find.byKey(AppKeys.historyFilterChips), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }

    testFilter('pages past the first day asked for are waited for no longer', (tester) async {
      final page = Completer<Iterable<Workout>>();
      await pumpApp(
        tester,
        history: recent,
        account: true,
        stub: (db, api) {
          when(db.isHistoryBackfilled(any)).thenAnswer((_) async => false);
          when(db.mirrorSummary(any)).thenAnswer(
            (_) async => const AccountSummary(
              collections: {ExportableCollection.workouts: CollectionSummary(count: 12)},
            ),
          );
          when(api.getAccountSummary()).thenAnswer(
            (_) async => const AccountSummary(
              collections: {ExportableCollection.workouts: CollectionSummary(count: 13)},
            ),
          );
          when(api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since'))).thenAnswer(
            (invocation) => switch (invocation.namedArguments[#since]) {
              null => Future.value(Page(items: recent.reversed.toList(), hasMore: true)),
              _ => page.future,
            },
          );
        },
      );
      final context = tester.element(find.byType(HistoryPage));
      unawaited(Backfill.of(context).run('u1'));
      // the fixtures' ids were made as the test ran: that is how far it reaches
      final reach = Workouts.of(context).pagedBackTo!.toLocal();
      HistoryFilter.of(context)
        ..toggle(.legs)
        ..from = reach.subtract(const Duration(days: 2));
      await tester.pumpTimes();
      expect(find.text('Looking through older workouts…'), findsOneWidget);

      HistoryFilter.of(context).from = reach.add(const Duration(days: 2));
      await tester.pumpTimes();
      expect(find.text('Looking through older workouts…'), findsNothing);
      expect(find.byKey(AppKeys.historyFilterEmpty), findsOneWidget);

      page.complete(Page(items: [older], hasMore: false));
      await tester.pumpTimes();
      expect(tester.takeException(), isNull);
    });
  });
}
