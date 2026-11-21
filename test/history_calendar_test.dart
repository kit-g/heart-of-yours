import 'dart:math';
import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/core/utils/visual.dart' show calendarWidth;
import 'package:heart/presentation/widgets/appbar_textfield.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

class _Workouts extends Workouts {
  new() : super(service: MockWorkoutService(), remoteService: MockRemoteWorkoutService());

  final rows = <String, List<Workout>>{};
  bool more = false;
  bool loading = false;
  bool error = false;
  int calls = 0;

  @override
  Map<String, List<Workout>> get byMonth => rows;
  @override
  bool get hasMoreHistory => more;
  @override
  bool get loadingMoreHistory => loading;
  @override
  bool get historyPageError => error;
  @override
  Future<void> loadMoreHistory() async {
    calls++;
    loading = true;
    notifyListeners();
  }
}

void main() {
  // A fixed day, mid-month, read through package:clock as the calendar reads
  // it: no fixture's day is "today" by accident (#618), whatever day the
  // suite runs on.
  final now = DateTime(2026, 11, 20, 12);
  void testCalendar(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) => withClock(Clock.fixed(now), () => body(tester)));
  }

  final current = DateTime(now.year, now.month);
  final previous = DateTime(now.year, now.month - 1);
  final before = DateTime(now.year, now.month - 2);
  String key(DateTime date) => DateFormat('yyyy-MM').format(date);
  Workout workout(DateTime month, int day) => Workout(name: 'Session')..start = DateTime(month.year, month.month, day);

  Future<void> pump(
    WidgetTester tester,
    _Workouts workouts, {
    Size size = const Size(390, 844),
    Locale locale = const Locale('en'),
    int? firstWeekday,
    void Function(Workout)? onTapWorkout,
    bool opens = true,
    void Function(DateTime)? onLogOn,
    VoidCallback? onStartWorkout,
    Map<String, Object> stored = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'firstWeekday': ?firstWeekday, ...stored});
    final preferences = Preferences();
    await tester.runAsync(() => preferences.init(locale: locale));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => HistoryCalendar(
                byMonth: Workouts.watch(context).byMonth,
                onTapWorkout: switch (opens) {
                  true => onTapWorkout ?? (_) {},
                  false => null,
                },
                onLogOn: onLogOn,
                onStartWorkout: onStartWorkout,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // a day's count, told from the day numbers by its weight
  Finder badge(int count) => find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == '$count' && widget.style?.fontWeight == FontWeight.w700,
  );

  testCalendar('one mark per completed day; empty days have no action', (tester) async {
    final semantics = tester.ensureSemantics();

    final workouts = _Workouts()..rows[key(current)] = [workout(current, 5), workout(current, 5), workout(current, 8)];
    await pump(tester, workouts);
    // the 5th holds two: a count, not a second check (#619)
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(badge(2), findsOneWidget);
    final marked = tester.getSemantics(
      find.bySemanticsLabel('${DateFormat.yMMMMEEEEd('en').format(DateTime(now.year, now.month, 8))}, edit workout'),
    );
    expect(marked.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    final empty = tester.getSemantics(
      find.bySemanticsLabel(DateFormat.yMMMMEEEEd('en').format(DateTime(now.year, now.month, 6))),
    );
    expect(empty.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testCalendar('one workout opens straight away, its day announced as one to edit (#619)', (tester) async {
    final opened = <Workout>[];
    await pump(tester, _Workouts()..rows[key(current)] = [workout(current, 5)], onTapWorkout: opened.add);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(opened.single.name, 'Session');
    expect(find.byType(PopupMenuItem<Object>), findsNothing);
  });

  for (final count in [2, 3, 4]) {
    testCalendar('a day of $count workouts shows and announces its count, and asks which (#619)', (tester) async {
      final semantics = tester.ensureSemantics();
      final sessions = [
        for (final hour in List.generate(count, (i) => 7 + i * 4))
          Workout(name: 'At $hour')..start = DateTime(current.year, current.month, 5, hour),
      ].reversed.toList();
      final opened = <Workout>[];
      await pump(tester, _Workouts()..rows[key(current)] = sessions, onTapWorkout: opened.add);
      expect(badge(count), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      final label = '${DateFormat.yMMMMEEEEd('en').format(DateTime(current.year, current.month, 5))}, $count workouts';
      final day = tester.getSemantics(find.bySemanticsLabel(label));
      expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      final items = find.byType(PopupMenuItem<Object>);
      expect(items, findsNWidgets(count));
      // earliest first
      expect(tester.getTopLeft(find.text('At 7')).dy, lessThan(tester.getTopLeft(find.text('At 11')).dy));
      await tester.tap(find.text('At 11'));
      await tester.pumpAndSettle();
      expect(opened.single.name, 'At 11');
      semantics.dispose();
    });
  }

  // Starts are UTC in the app (`DateTime.timestamp()`, ISO strings ending in
  // Z), so these give them as UTC; run under a zone west of Greenwich
  // (`TZ=America/Toronto`) they cross into the next UTC day.
  testCalendar('a workout counts on the day it started on the user\'s clock (#619)', (tester) async {
    final semantics = tester.ensureSemantics();
    final morning = Workout(name: 'Morning')..start = DateTime(current.year, current.month, 5, 10).toUtc();
    final late = Workout(name: 'Late')..start = DateTime(current.year, current.month, 5, 23, 30).toUtc();
    late.finish(late.start.add(const Duration(hours: 1)));
    final next = Workout(name: 'Next')..start = DateTime(current.year, current.month, 6, 8).toUtc();
    await pump(tester, _Workouts()..rows[key(current)] = [next, late, morning]);
    final date = DateFormat.yMMMMEEEEd('en');
    expect(
      find.bySemanticsLabel('${date.format(DateTime(current.year, current.month, 5))}, 2 workouts'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('${date.format(DateTime(current.year, current.month, 6))}, edit workout'),
      findsOneWidget,
    );

    // and the list tells them apart by the user's time, not UTC's
    await tester.tap(find.bySemanticsLabel('${date.format(DateTime(current.year, current.month, 5))}, 2 workouts'));
    await tester.pumpAndSettle();
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(find.text('11:30 PM'), findsOneWidget);
    semantics.dispose();
  });

  testCalendar('a trained day is marked even where it opens nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, _Workouts()..rows[key(current)] = [workout(current, 5)], opens: false);
    expect(find.byIcon(Icons.check), findsOneWidget);
    final day = tester.getSemantics(
      find.bySemanticsLabel('${DateFormat.yMMMMEEEEd('en').format(DateTime(now.year, now.month, 5))}, 1 workout'),
    );
    expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  group('a day is a way in (#618)', () {
    // built in the tests, once the app has loaded its locale data
    String said(int day) => DateFormat.yMMMMEEEEd('en').format(DateTime(now.year, now.month, day));
    const on = {'feature-pastWorkouts': 'on'};
    const off = {'feature-pastWorkouts': 'off'};

    testCalendar('with Past workouts on, an empty past day logs a workout on it', (tester) async {
      final semantics = tester.ensureSemantics();
      final logged = <DateTime>[];
      await pump(tester, _Workouts(), onLogOn: logged.add, stored: on);
      await tester.tap(find.bySemanticsLabel('${said(10)}, log a workout on this day'));
      await tester.pumpAndSettle();
      expect(logged, [DateTime(now.year, now.month, 10)]);
      semantics.dispose();
    });

    testCalendar('never asked, the first empty past day asks; yes turns it on and logs that day', (tester) async {
      final semantics = tester.ensureSemantics();
      final logged = <DateTime>[];
      await pump(tester, _Workouts(), onLogOn: logged.add);
      await tester.tap(find.bySemanticsLabel('${said(10)}, log a workout on this day'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.pastWorkoutsOffer), findsOneWidget);
      expect(logged, isEmpty);

      await tester.tap(find.byKey(AppKeys.pastWorkoutsAccept));
      await tester.pumpAndSettle();
      final preferences = Preferences.of(tester.element(find.byType(HistoryCalendar)));
      expect(preferences.isOn(.pastWorkouts), isTrue);
      expect(logged, [DateTime(now.year, now.month, 10)]);
      semantics.dispose();
    });

    testCalendar('a no is told once where the switch is, and the day then offers nothing', (tester) async {
      final semantics = tester.ensureSemantics();
      final logged = <DateTime>[];
      await pump(tester, _Workouts(), onLogOn: logged.add);
      await tester.tap(find.bySemanticsLabel('${said(10)}, log a workout on this day'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.pastWorkoutsDecline));
      await tester.pumpAndSettle();
      final l = L.of(tester.element(find.byType(HistoryCalendar)));
      expect(find.text(l.featureDeclinedNotice), findsOneWidget);
      expect(logged, isEmpty);
      final preferences = Preferences.of(tester.element(find.byType(HistoryCalendar)));
      expect(preferences.featureAnswer(.pastWorkouts), FeatureAnswer.off);

      final day = tester.getSemantics(find.bySemanticsLabel(said(10)));
      expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    });

    testCalendar('with Past workouts off, an empty past day does nothing', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _Workouts(), onLogOn: (_) => fail('logged'), stored: off);
      final day = tester.getSemantics(find.bySemanticsLabel(said(10)));
      expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    });

    testCalendar('today starts a workout, or logs one while Past workouts is on', (tester) async {
      final semantics = tester.ensureSemantics();
      final logged = <DateTime>[];
      var started = 0;
      await pump(tester, _Workouts(), onLogOn: logged.add, onStartWorkout: () => started++, stored: on);
      await tester.tap(find.bySemanticsLabel('${said(20)}, today'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.calendarStart), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.calendarLog));
      await tester.pumpAndSettle();
      expect(logged, [DateTime(now.year, now.month, 20)]);

      await tester.tap(find.bySemanticsLabel('${said(20)}, today'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.calendarStart));
      await tester.pumpAndSettle();
      expect(started, 1);
      semantics.dispose();
    });

    testCalendar('with Past workouts off, today only starts one', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _Workouts(), onLogOn: (_) => fail('logged'), onStartWorkout: () {}, stored: off);
      await tester.tap(find.bySemanticsLabel('${said(20)}, today'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.calendarStart), findsOneWidget);
      expect(find.byKey(AppKeys.calendarLog), findsNothing);
      semantics.dispose();
    });

    testCalendar('a trained day offers its workout and another one on it', (tester) async {
      final semantics = tester.ensureSemantics();
      final logged = <DateTime>[];
      final opened = <Workout>[];
      await pump(
        tester,
        _Workouts()..rows[key(current)] = [workout(current, 5)],
        onTapWorkout: opened.add,
        onLogOn: logged.add,
        stored: on,
      );
      await tester.tap(find.bySemanticsLabel('${said(5)}, 1 workout'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<Object>), findsNWidgets(2));
      expect(find.text('Add another'), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.calendarLog));
      await tester.pumpAndSettle();
      expect(logged, [DateTime(now.year, now.month, 5)]);
      expect(opened, isEmpty);
      semantics.dispose();
    });

    testCalendar('a day before the oldest workout fetched is not taken for empty while more is to come', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        _Workouts()
          ..more = true
          ..rows[key(current)] = [workout(current, 15)],
        onLogOn: (_) {},
        stored: on,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(said(10))).getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(find.bySemanticsLabel('${said(18)}, log a workout on this day'), findsOneWidget);
      semantics.dispose();
    });

    testCalendar('a day that opens nothing lists no workouts, only what it can do', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        _Workouts()..rows[key(current)] = [workout(current, 5)],
        opens: false,
        onLogOn: (_) {},
        stored: on,
      );
      await tester.tap(find.bySemanticsLabel('${said(5)}, 1 workout'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<Object>), findsOneWidget);
      expect(find.byKey(AppKeys.calendarLog), findsOneWidget);
      semantics.dispose();
    });

    testCalendar('a future day does nothing', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _Workouts(), onLogOn: (_) => fail('logged'), onStartWorkout: () {}, stored: on);
      final day = tester.getSemantics(find.bySemanticsLabel(said(25)));
      expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    });
  });

  testCalendar('empty intervening month renders; scrolling stops at loaded window', (tester) async {
    final workouts = _Workouts()
      ..rows[key(current)] = [workout(current, 5)]
      ..rows[key(before)] = [workout(before, 5)];
    await pump(tester, workouts);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text(DateFormat.yMMM('en').format(previous)), findsOneWidget);
    expect(find.byKey(ValueKey(key(DateTime(now.year, now.month - 3)))), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testCalendar('oldest month requests once, never while loading or erroring; retry is explicit', (tester) async {
    final workouts = _Workouts()
      ..more = true
      ..rows[key(current)] = [workout(current, 5)];
    await pump(tester, workouts);
    expect(workouts.calls, 1);
    await tester.pump();
    expect(workouts.calls, 1);
    workouts.loading = false;
    workouts.error = true;
    workouts.notifyListeners();
    await tester.pump();
    await tester.pump();
    expect(workouts.calls, 1);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(workouts.calls, 2);
  });

  testCalendar('an older page extends upward without moving the visible months', (tester) async {
    final workouts = _Workouts()
      ..rows[key(current)] = [workout(current, 5)]
      ..rows[key(previous)] = [workout(previous, 5)];
    await pump(tester, workouts);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    scroll.jumpTo(40);
    await tester.pump();
    final month = find.byKey(ValueKey(key(current)));
    final position = tester.getTopLeft(month);
    workouts.rows[key(before)] = [workout(before, 5)];
    workouts.notifyListeners();
    await tester.pump();
    expect(scroll.pixels, 40);
    expect(tester.getTopLeft(month), position);
    expect(tester.takeException(), isNull);
  });

  Future<MockLocalDatabase> pumpApp(
    WidgetTester tester, {
    required Size size,
    required List<Workout> history,
    Map<String, Object> stored = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    // after the stubs, which seed the preferences of a device past onboarding
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...stored});
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => history);
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(mockUser: MockUser(uid: 'u1', isAnonymous: true), signedIn: true),
      settle: false,
    );
    await tester.tapByKey(AppKeys.historyStack);
    await tester.pumpTimes();
    return db;
  }

  // the day's own Semantics widget: the calendar's months sit in a viewport
  // inside History's, and the label finder does not reach through to them
  Finder day(String label) =>
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

  Workout finished(DateTime month, int day) {
    final workout = Workout(name: 'Session')..start = DateTime(month.year, month.month, day, 9);
    workout.add(Exercise(name: 'Bench Press', category: .barbell, target: .chest));
    return workout..finish(workout.start.add(const Duration(hours: 1)));
  }

  testCalendar('the switch turns History into the calendar and back, and History opens on the last one (#609)', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(390, 844), history: [finished(current, 5)]);
    expect(find.byKey(AppKeys.historyCalendar), findsNothing);
    final preferences = Preferences.of(tester.element(find.byType(HistoryPage)));
    expect(preferences.historyView, HistoryView.list);

    await tester.tap(find.byTooltip('Show as calendar'));
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
    expect(find.byType(WorkoutItem), findsNothing);
    expect(preferences.historyView, HistoryView.calendar);
    // the list's actions stay in the calendar's header
    expect(find.byTooltip('Show as list'), findsOneWidget);

    await tester.tap(find.byTooltip('Show as list'));
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.historyCalendar), findsNothing);
    expect(find.byType(WorkoutItem), findsOneWidget);
    expect(preferences.historyView, HistoryView.list);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(1194, 834)]) {
    testCalendar('the list and the calendar turn into each other under a header that stays put, at $size (#712)', (
      tester,
    ) async {
      await pumpApp(tester, size: size, history: [finished(current, 5)]);
      // while the two swap, both headers are built: the arriving one is on top
      Finder header() => find.byKey(AppKeys.historyViewSwitch).last;
      final at = tester.getRect(header());

      await tester.tap(header());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
      expect(find.byType(WorkoutItem), findsOneWidget, reason: 'the list is still leaving');
      final arriving = tester.widget<SliverFadeTransition>(
        find.ancestor(of: find.byKey(AppKeys.historyCalendar), matching: find.byType(SliverFadeTransition)).first,
      );
      expect(arriving.opacity.value, inExclusiveRange(0, 1));
      expect(tester.getRect(header()), at);
      await tester.pumpTimes();
      expect(find.byType(WorkoutItem), findsNothing);
      expect(find.byKey(AppKeys.historyViewSwitch), findsOneWidget);
      expect(tester.getRect(header()), at);

      await tester.tap(header());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(AppKeys.historyCalendar), findsOneWidget, reason: 'the calendar is still leaving');
      expect(find.byType(WorkoutItem), findsOneWidget);
      expect(tester.getRect(header()), at);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.historyCalendar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, features) in [
    ('Reduce Motion', const FakeAccessibilityFeatures(reduceMotion: true)),
    ('Remove animations', const FakeAccessibilityFeatures(disableAnimations: true)),
  ]) {
    testCalendar('with $name, the switch changes the view at once (#712)', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpApp(tester, size: const Size(390, 844), history: [finished(current, 5)]);

      await tester.tap(find.byTooltip('Show as calendar'));
      await tester.pump();
      expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
      expect(find.byType(WorkoutItem), findsNothing);
      expect(find.byKey(AppKeys.historyViewSwitch), findsOneWidget);

      await tester.tap(find.byTooltip('Show as list'));
      await tester.pump();
      expect(find.byKey(AppKeys.historyCalendar), findsNothing);
      expect(find.byType(WorkoutItem), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testCalendar("the calendar does not inherit the list's scroll (#609)", (tester) async {
    final history = [for (final day in List.generate(12, (i) => 2 + i * 2)) finished(current, day)];
    await pumpApp(tester, size: const Size(390, 844), history: history);
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    list.position.jumpTo(300);
    await tester.pumpTimes();

    await tester.tap(find.byTooltip('Show as calendar'));
    await tester.pumpTimes();
    final frame = tester.state<ScrollableState>(
      find.ancestor(of: find.byKey(AppKeys.historyCalendar), matching: find.byType(Scrollable)).first,
    );
    expect(frame.position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testCalendar('edits discarded in a workout opened from the calendar never reach History (#609)', (tester) async {
    final session = finished(current, 5);
    await pumpApp(tester, size: const Size(1194, 834), history: [session]);
    final context = tester.element(find.byType(HistoryPage));
    Preferences.of(context).setHistoryView(.calendar);
    await tester.pumpTimes();
    await tester.tap(day('${DateFormat.yMMMMEEEEd('en').format(session.start)}, edit workout'));
    await tester.pumpTimes();

    await tester.enterText(
      find.descendant(of: find.byType(AppBarTextField), matching: find.byType(TextField)),
      'Changed name',
    );
    await tester.pumpTimes();
    final l = L.of(tester.element(find.byType(WorkoutEditor)));
    await tester.tap(find.byKey(AppKeys.closeDetail));
    await tester.pumpTimes();
    await tester.tap(find.text(l.quitPage));
    await tester.pumpTimes();
    expect(Workouts.of(context).lookup(session.id)?.name, 'Session');
    expect(tester.takeException(), isNull);
  });

  testWidgets('today moves at midnight, with the page left open (#618)', (tester) async {
    var at = DateTime(2026, 11, 20, 23, 59);
    await withClock(Clock(() => at), () async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _Workouts(), onStartWorkout: () {});
      String said(int day) => DateFormat.yMMMMEEEEd('en').format(DateTime(2026, 11, day));
      expect(find.bySemanticsLabel('${said(20)}, today'), findsOneWidget);

      at = DateTime(2026, 11, 21, 0, 1);
      await tester.pump(const Duration(minutes: 2));
      expect(find.bySemanticsLabel('${said(21)}, today'), findsOneWidget);
      expect(find.bySemanticsLabel('${said(20)}, today'), findsNothing);
      semantics.dispose();
    });
  });

  testWidgets('just after midnight, a workout logged on today starts today (#618)', (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 20, 0, 20)), () async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        size: const Size(1194, 834),
        history: const [],
        stored: {
          'feature-pastWorkouts': 'on',
          'screen-historyView': 'calendar',
          'screen-historyView-at': '2026-11-01T00:00:00.000Z',
        },
      );
      final today = DateTime(2026, 11, 20);
      await tester.tap(day('${DateFormat.yMMMMEEEEd('en').format(today)}, today'));
      await tester.pumpTimes();
      await tester.tap(find.byKey(AppKeys.calendarLog));
      await tester.pumpTimes();
      final l = L.of(tester.element(find.byType(HistoryPage)));
      await tester.tap(find.text(l.next));
      await tester.pumpTimes();
      final logging = tester.widget<WorkoutEditor>(find.byType(WorkoutEditor)).copy;
      expect(logging.start.toLocal(), today);
      semantics.dispose();
    });
  });

  testCalendar('a workout logged from an empty day is on that day (#618)', (tester) async {
    final semantics = tester.ensureSemantics();
    // a tablet: the times dialog's rows overflow a phone under the test font
    await pumpApp(tester, size: const Size(1194, 834), history: const [], stored: {'feature-pastWorkouts': 'on'});
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.calendar);
    await tester.pumpTimes();
    final tenth = DateTime(now.year, now.month, 10);
    await tester.tap(day('${DateFormat.yMMMMEEEEd('en').format(tenth)}, log a workout on this day'));
    await tester.pumpTimes();
    final l = L.of(tester.element(find.byType(HistoryPage)));
    expect(find.text(l.whenWasIt), findsOneWidget);
    await tester.tap(find.text(l.next));
    await tester.pumpTimes();
    final logging = tester.widget<WorkoutEditor>(find.byType(WorkoutEditor)).copy;
    expect(DateUtils.dateOnly(logging.start.toLocal()), tenth);
    expect(DateUtils.dateOnly(logging.end!.toLocal()), tenth);
    semantics.dispose();
  });

  testCalendar('a marked day opens its workout in the detail pane, and marks itself (#609)', (tester) async {
    final semantics = tester.ensureSemantics();
    final session = finished(current, 5);
    await pumpApp(tester, size: const Size(1194, 834), history: [session]);
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.calendar);
    await tester.pumpTimes();

    final label = '${DateFormat.yMMMMEEEEd('en').format(session.start)}, edit workout';
    await tester.tap(day(label));
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsOneWidget);
    // the calendar stays where it was, in the master pane beside it
    expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(WorkoutEditor)).dx,
      greaterThanOrEqualTo(tester.getTopRight(find.byKey(AppKeys.historyCalendar)).dx),
    );
    expect(tester.getSemantics(day(label)).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testCalendar('a marked day on a phone pushes its workout over the calendar (#609)', (tester) async {
    final session = finished(current, 5);
    await pumpApp(tester, size: const Size(390, 844), history: [session]);
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.calendar);
    await tester.pumpTimes();
    final semantics = tester.ensureSemantics();
    await tester.tap(day('${DateFormat.yMMMMEEEEd('en').format(session.start)}, edit workout'));
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testCalendar('on a tablet the list of a day opens at the day, not a rail away (#619)', (tester) async {
    final semantics = tester.ensureSemantics();
    final first = finished(current, 5);
    final second = finished(current, 5)..start = DateTime(current.year, current.month, 5, 18);
    await pumpApp(tester, size: const Size(1194, 834), history: [second, first]);
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.calendar);
    await tester.pumpTimes();
    final label = '${DateFormat.yMMMMEEEEd('en').format(first.start)}, 2 workouts';
    final rect = tester.getRect(day(label));
    await tester.tap(day(label));
    await tester.pumpTimes();
    final items = find.byType(PopupMenuItem<Object>);
    expect(items, findsNWidgets(2));
    final menu = tester.getRect(items.first);
    // hung off whichever edge of the day has the room: its left, or its right
    // once the day sits in the right half of the page
    final off = [(menu.left - rect.left).abs(), (menu.right - rect.right).abs()].reduce(min);
    expect(off, lessThan(rect.width), reason: 'menu at $menu, day at $rect');

    // the earlier one into the pane; asked again, the list checks it
    await tester.tap(items.first);
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsOneWidget);
    await tester.tap(day(label));
    await tester.pumpTimes();
    final checked = tester.widgetList<CheckedPopupMenuItem<Object>>(find.byType(CheckedPopupMenuItem<Object>));
    expect(
      [for (final item in checked) ((item.value as Workout?)?.id, item.checked)],
      [(first.id, true), (second.id, false)],
    );
    semantics.dispose();
  });

  for (final size in [const Size(390, 844), const Size(834, 1194), const Size(1194, 834)]) {
    testCalendar('calendar is capped and fits $size', (tester) async {
      await pump(tester, _Workouts(), size: size);
      final months = find.descendant(of: find.byType(HistoryCalendar), matching: find.byType(ListView));
      expect(tester.getSize(months).width, lessThanOrEqualTo(calendarWidth));
      expect(tester.takeException(), isNull);
    });
  }

  testCalendar('Russian starts Monday, English starts Sunday', (tester) async {
    final semantics = tester.ensureSemantics();

    await pump(tester, _Workouts(), locale: const Locale('ru'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.bySemanticsLabel('понедельник')).dx,
      lessThan(tester.getTopLeft(find.bySemanticsLabel('воскресенье')).dx),
    );
    await pump(tester, _Workouts());
    expect(
      tester.getTopLeft(find.bySemanticsLabel('Sunday')).dx,
      lessThan(tester.getTopLeft(find.bySemanticsLabel('Monday')).dx),
    );
    semantics.dispose();
  });

  testCalendar("the user's first day wins over the locale's (#339)", (tester) async {
    final semantics = tester.ensureSemantics();

    await pump(tester, _Workouts(), firstWeekday: DateTime.saturday);
    final saturday = tester.getTopLeft(find.bySemanticsLabel('Saturday')).dx;
    for (final day in ['Sunday', 'Monday', 'Friday']) {
      expect(saturday, lessThan(tester.getTopLeft(find.bySemanticsLabel(day)).dx), reason: day);
    }
    semantics.dispose();
  });
}
