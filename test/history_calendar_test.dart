import 'dart:math';
import 'dart:ui' show Tristate;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDatePicker;
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
    Set<DaySource> sources = const {},
    void Function(DaySource source, {DateTime? on})? onMakeFrom,
    Map<String, Object> stored = const {},
    bool paged = false,
    PageController? pages,
    TargetPlatform platform = .android,
    bool Function(Workout)? shows,
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
          theme: ThemeData(platform: platform),
          locale: locale,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => HistoryCalendar(
                byMonth: Workouts.watch(context).byMonth,
                paged: paged,
                pages: pages,
                shows: shows,
                onTapWorkout: switch (opens) {
                  true => onTapWorkout ?? (_) {},
                  false => null,
                },
                onLogOn: onLogOn,
                onStartWorkout: onStartWorkout,
                sources: sources,
                onMakeFrom: onMakeFrom,
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

    for (final paged in [false, true]) {
      group('made from something${paged ? ', a month at a time' : ''} (#737)', () {
        const both = {DaySource.template, DaySource.workout};
        late List<(DaySource, DateTime?)> made;
        setUp(() => made = []);
        void make(DaySource source, {DateTime? on}) => made.add((source, on));

        Future<void> tapDay(WidgetTester tester, String label) async {
          await tester.tap(find.bySemanticsLabel(label));
          await tester.pumpAndSettle();
        }

        testCalendar('an empty past day asks how: logged empty, from a template or from a workout', (tester) async {
          final semantics = tester.ensureSemantics();
          final logged = <DateTime>[];
          await pump(
            tester,
            _Workouts(),
            onLogOn: logged.add,
            sources: both,
            onMakeFrom: make,
            stored: on,
            paged: paged,
          );
          final tenth = DateTime(now.year, now.month, 10);
          for (final (key, source) in [
            (AppKeys.calendarFromTemplate, DaySource.template),
            (AppKeys.calendarFromWorkout, DaySource.workout),
          ]) {
            await tapDay(tester, '${said(10)}, log a workout on this day');
            expect(find.byType(PopupMenuItem<Object>), findsNWidgets(3));
            expect(find.byKey(AppKeys.calendarStart), findsNothing);
            await tester.tap(find.byKey(key));
            await tester.pumpAndSettle();
            expect(made.last, (source, tenth));
          }
          expect(logged, isEmpty);
          await tapDay(tester, '${said(10)}, log a workout on this day');
          await tester.tap(find.byKey(AppKeys.calendarLog));
          await tester.pumpAndSettle();
          expect(logged, [tenth]);
          semantics.dispose();
        });

        testCalendar('only what there is any of is offered', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(
            tester,
            _Workouts(),
            onLogOn: (_) {},
            sources: {DaySource.template},
            onMakeFrom: make,
            stored: on,
            paged: paged,
          );
          await tapDay(tester, '${said(10)}, log a workout on this day');
          expect(find.byKey(AppKeys.calendarFromTemplate), findsOneWidget);
          expect(find.byKey(AppKeys.calendarFromWorkout), findsNothing);
          semantics.dispose();
        });

        testCalendar('never asked, an empty past day asks first; yes opens the ways', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(
            tester,
            _Workouts(),
            onLogOn: (_) => fail('logged'),
            sources: both,
            onMakeFrom: make,
            paged: paged,
          );
          await tapDay(tester, '${said(10)}, log a workout on this day');
          expect(find.byKey(AppKeys.pastWorkoutsOffer), findsOneWidget);
          expect(find.byType(PopupMenuItem<Object>), findsNothing);
          await tester.tap(find.byKey(AppKeys.pastWorkoutsAccept));
          await tester.pumpAndSettle();
          expect(find.byType(PopupMenuItem<Object>), findsNWidgets(3));
          await tester.tap(find.byKey(AppKeys.calendarFromWorkout));
          await tester.pumpAndSettle();
          expect(made, [(DaySource.workout, DateTime(now.year, now.month, 10))]);
          semantics.dispose();
        });

        testCalendar('with Past workouts off, a past day offers neither, trained or not', (tester) async {
          final semantics = tester.ensureSemantics();
          final opened = <Workout>[];
          await pump(
            tester,
            _Workouts()..rows[key(current)] = [workout(current, 5)],
            onTapWorkout: opened.add,
            onLogOn: (_) => fail('logged'),
            sources: both,
            onMakeFrom: make,
            stored: off,
            paged: paged,
          );
          final day = tester.getSemantics(find.bySemanticsLabel(said(10)));
          expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
          await tapDay(tester, '${said(5)}, edit workout');
          expect(opened, hasLength(1));
          semantics.dispose();
        });

        testCalendar('today makes one that starts, with Past workouts off too', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(
            tester,
            _Workouts(),
            onLogOn: (_) => fail('logged'),
            onStartWorkout: () {},
            sources: both,
            onMakeFrom: make,
            stored: off,
            paged: paged,
          );
          for (final (key, source) in [
            (AppKeys.calendarFromTemplate, DaySource.template),
            (AppKeys.calendarFromWorkout, DaySource.workout),
          ]) {
            await tapDay(tester, '${said(20)}, today');
            expect(find.byKey(AppKeys.calendarLog), findsNothing);
            await tester.tap(find.byKey(key));
            await tester.pumpAndSettle();
            expect(made.last, (source, null));
          }
          semantics.dispose();
        });

        testCalendar('today with a workout going starts nothing, and so makes nothing', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(
            tester,
            _Workouts(),
            onLogOn: (_) {},
            sources: both,
            onMakeFrom: make,
            stored: on,
            paged: paged,
          );
          await tapDay(tester, '${said(20)}, today');
          expect(find.byKey(AppKeys.calendarLog), findsOneWidget);
          expect(find.byKey(AppKeys.calendarFromTemplate), findsNothing);
          expect(find.byKey(AppKeys.calendarFromWorkout), findsNothing);
          semantics.dispose();
        });

        testCalendar('a trained past day offers them after another', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(
            tester,
            _Workouts()..rows[key(current)] = [workout(current, 5)],
            onLogOn: (_) {},
            sources: both,
            onMakeFrom: make,
            stored: on,
            paged: paged,
          );
          await tapDay(tester, '${said(5)}, 1 workout');
          expect(find.byType(PopupMenuItem<Object>), findsNWidgets(4));
          await tester.tap(find.byKey(AppKeys.calendarFromTemplate));
          await tester.pumpAndSettle();
          expect(made, [(DaySource.template, DateTime(now.year, now.month, 5))]);
          semantics.dispose();
        });
      });
    }

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

  group('a month at a time (#739)', () {
    String named(WidgetTester tester) => tester.widget<Text>(find.byKey(AppKeys.calendarMonthTitle)).data!;
    String name(DateTime month, [String locale = 'en']) => DateFormat.yMMM(locale).format(month);
    _Workouts three() => _Workouts()
      ..rows[key(current)] = [workout(current, 5)]
      ..rows[key(previous)] = [workout(previous, 6)]
      ..rows[key(before)] = [workout(before, 7)];

    Future<void> swipe(WidgetTester tester, double dx) async {
      await tester.fling(find.byType(PageView), Offset(dx, 0), 1000);
      await tester.pumpAndSettle();
    }

    /// Onto the page still to come, whose spinner never settles.
    Future<void> swipeOn(WidgetTester tester) async {
      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await tester.pumpTimes();
    }

    testCalendar('a swipe turns the months, no further than the current one and the oldest', (tester) async {
      await pump(tester, three(), paged: true);
      expect(named(tester), name(current));
      expect(find.byKey(ValueKey(key(current))), findsOneWidget);
      expect(find.byKey(ValueKey(key(previous))), findsNothing);

      await swipe(tester, -300);
      expect(named(tester), name(current), reason: 'nothing is later');
      await swipe(tester, 300);
      expect(named(tester), name(previous));
      await swipe(tester, 300);
      expect(named(tester), name(before));
      await swipe(tester, 300);
      expect(named(tester), name(before), reason: 'nothing is older');
      await swipe(tester, -300);
      expect(named(tester), name(previous));
      expect(tester.takeException(), isNull);
    });

    testCalendar('a workout dated past the current month adds no later one', (tester) async {
      final next = DateTime(now.year, now.month + 1);
      await pump(tester, _Workouts()..rows[key(next)] = [workout(next, 3)], paged: true);
      expect(named(tester), name(current));
      expect(find.byKey(AppKeys.calendarNextMonth).hitTestable(), findsNothing);
      expect(find.byKey(AppKeys.calendarPreviousMonth).hitTestable(), findsNothing);
    });

    testCalendar('the buttons turn the months, each gone where there is none, the other not moving', (tester) async {
      await pump(tester, three(), paged: true);
      final back = tester.getRect(find.byKey(AppKeys.calendarPreviousMonth));
      expect(find.byKey(AppKeys.calendarNextMonth).hitTestable(), findsNothing);
      await tester.tap(find.byKey(AppKeys.calendarPreviousMonth));
      await tester.pumpAndSettle();
      expect(named(tester), name(previous));
      expect(tester.getRect(find.byKey(AppKeys.calendarPreviousMonth)), back);
      await tester.tap(find.byKey(AppKeys.calendarPreviousMonth));
      await tester.pumpAndSettle();
      expect(named(tester), name(before));
      expect(find.byKey(AppKeys.calendarPreviousMonth).hitTestable(), findsNothing);
      await tester.tap(find.byKey(AppKeys.calendarNextMonth));
      await tester.pumpAndSettle();
      expect(named(tester), name(previous));
    });

    for (final locale in const ['en', 'ru', 'es', 'fr']) {
      testCalendar('the month is announced as it changes, in $locale', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, three(), paged: true, locale: Locale(locale));
        await swipe(tester, 300);
        final said = DateFormat.yMMMM(locale).format(previous);
        final node = tester.getSemantics(find.bySemanticsLabel(said)).getSemanticsData();
        expect(node.flagsCollection.isLiveRegion, isTrue);
        semantics.dispose();
      });
    }

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testCalendar('a date picked goes to its month, on $platform', (tester) async {
        final far = DateTime(now.year - 2, 3);
        await pump(
          tester,
          _Workouts()
            ..rows[key(current)] = [workout(current, 5)]
            ..rows[key(far)] = [workout(far, 9)],
          paged: true,
          platform: platform,
        );
        await tester.tap(find.byKey(AppKeys.calendarGoToDate));
        await tester.pumpAndSettle();
        switch (platform) {
          case TargetPlatform.iOS:
            // month, day, year: two years back, and it stays there
            await tester.drag(find.text('${now.year}'), const Offset(0, 64), touchSlopY: 0);
            await tester.pumpAndSettle(const Duration(milliseconds: 100));
            await tester.tap(find.text('OK'));
          case _:
            await tester.tap(find.text('November ${now.year}'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('${now.year - 2}'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('10').last);
            await tester.pumpAndSettle();
            await tester.tap(find.text('OK'));
        }
        await tester.pumpAndSettle();
        expect(named(tester), name(DateTime(now.year - 2, now.month)));
        expect(tester.takeException(), isNull);
      });
    }

    testCalendar('the oldest month asks for what is older, once, and the page after it fills in', (tester) async {
      final workouts = _Workouts()
        ..rows[key(current)] = [workout(current, 5)]
        ..more = true;
      await pump(tester, workouts, paged: true);
      await tester.pump();
      expect(workouts.calls, 1);
      await swipeOn(tester);
      expect(named(tester), name(current), reason: 'the page still to come is no month');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      workouts
        ..rows[key(previous)] = [workout(previous, 6)]
        ..loading = false
        ..more = false
        ..notifyListeners();
      await tester.pumpAndSettle();
      expect(named(tester), name(previous));
      expect(find.byKey(ValueKey(key(previous))), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testCalendar('a tail with nothing older goes back to the oldest month', (tester) async {
      final workouts = _Workouts()
        ..rows[key(current)] = [workout(current, 5)]
        ..more = true;
      await pump(tester, workouts, paged: true);
      await tester.pump();
      await swipeOn(tester);
      workouts
        ..loading = false
        ..more = false
        ..notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(key(current))), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a month beginning with the page open leaves the one looked at', (tester) async {
      var at = DateTime(2026, 11, 30, 23, 59);
      await withClock(Clock(() => at), () async {
        await pump(tester, three(), paged: true);
        await swipe(tester, 300);
        expect(named(tester), name(previous));
        at = DateTime(2026, 12, 1, 0, 1);
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();
        expect(named(tester), name(previous));
        expect(find.byKey(ValueKey(key(previous))), findsOneWidget);
      });
    });

    testWidgets('a month beginning on the current one goes on being on the current one', (tester) async {
      var at = DateTime(2026, 11, 30, 23, 59);
      await withClock(Clock(() => at), () async {
        await pump(tester, three(), paged: true);
        at = DateTime(2026, 12, 1, 0, 1);
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();
        expect(named(tester), name(DateTime(2026, 12)));
        expect(find.byKey(const ValueKey('2026-12')), findsOneWidget);
      });
    });

    testCalendar('two quick taps turn two months', (tester) async {
      await pump(tester, three(), paged: true);
      await tester.tap(find.byKey(AppKeys.calendarPreviousMonth));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(AppKeys.calendarPreviousMonth));
      await tester.pumpAndSettle();
      expect(named(tester), name(before));
    });

    testCalendar('one month and nothing more to come: nowhere to go to', (tester) async {
      await pump(tester, _Workouts()..rows[key(current)] = [workout(current, 5)], paged: true);
      expect(find.byKey(AppKeys.calendarGoToDate), findsNothing);
    });

    testCalendar('a month not read yet is gone to as its history comes', (tester) async {
      final workouts = _Workouts()
        ..rows[key(current)] = [workout(current, 5)]
        ..more = true;
      await pump(tester, workouts, paged: true, platform: .iOS);
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.calendarGoToDate));
      await tester.pumpTimes();
      final wheel = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      expect(wheel.initialDateTime, current);
      wheel.onDateTimeChanged(before);
      await tester.pumpTimes();
      await tester.tap(find.text('OK'));
      await tester.pumpTimes();
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'the page still to come');

      // one month of it, and more to come: asked for again
      final calls = workouts.calls;
      workouts
        ..rows[key(previous)] = [workout(previous, 6)]
        ..loading = false
        ..notifyListeners();
      await tester.pumpTimes();
      expect(workouts.calls, greaterThan(calls));
      workouts
        ..rows[key(before)] = [workout(before, 7)]
        ..loading = false
        ..notifyListeners();
      await tester.pumpTimes();
      expect(named(tester), name(before));
    });

    testCalendar('swiping lets go of a month still being read for', (tester) async {
      final workouts = _Workouts()
        ..rows[key(current)] = [workout(current, 5)]
        ..more = true;
      await pump(tester, workouts, paged: true, platform: .iOS);
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.calendarGoToDate));
      await tester.pumpTimes();
      tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).onDateTimeChanged(before);
      await tester.tap(find.text('OK'));
      await tester.pumpTimes();
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpTimes();
      workouts
        ..rows[key(previous)] = [workout(previous, 6)]
        ..rows[key(before)] = [workout(before, 7)]
        ..loading = false
        ..more = false
        ..notifyListeners();
      await tester.pumpAndSettle();
      expect(named(tester), name(current));
    });

    testCalendar('a narrow pane keeps the name whole, on a row of its own', (tester) async {
      await pump(tester, three(), paged: true, size: const Size(208, 780));
      tester.takeException();
      final title = tester.getRect(find.byKey(AppKeys.calendarMonthTitle));
      expect(title.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(AppKeys.calendarGoToDate)).top));
    });

    testCalendar('a day opens its workout, and the filter marks as it does in the scrolling months', (tester) async {
      final opened = <Workout>[];
      await pump(
        tester,
        _Workouts()..rows[key(current)] = [workout(current, 5)..name = 'Legs', workout(current, 8)],
        paged: true,
        onTapWorkout: opened.add,
        shows: (workout) => workout.name == 'Legs',
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      expect(opened.single.name, 'Legs');
    });

    testCalendar('wider than a phone, the month keeps its width', (tester) async {
      await pump(tester, three(), paged: true, size: const Size(1194, 834));
      expect(tester.getSize(find.byType(PageView)).width, calendarWidth);
    });

    testCalendar('on a short screen a month of six weeks scrolls to its end', (tester) async {
      final six = DateTime(2026, 8);
      await pump(tester, _Workouts()..rows[key(six)] = [workout(six, 31)], paged: true, size: const Size(390, 420));
      for (final _ in [1, 2, 3]) {
        await swipe(tester, 300);
      }
      await tester.drag(find.byType(PageView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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

  /// Picks [view] off the menu of them: the menu is gone, and the swap not
  /// begun, when this returns.
  Future<void> show(WidgetTester tester, HistoryView view) async {
    await tester.tap(find.byKey(AppKeys.historyViewSwitch).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(AppKeys.historyViewChoice(view.value)));
  }

  testCalendar('the switch turns History into the calendar and back, and History opens on the last one (#609)', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(390, 844), history: [finished(current, 5)]);
    expect(find.byKey(AppKeys.historyCalendar), findsNothing);
    final preferences = Preferences.of(tester.element(find.byType(HistoryPage)));
    expect(preferences.historyView, HistoryView.list);

    await show(tester, .calendar);
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
    expect(find.byType(WorkoutItem), findsNothing);
    expect(preferences.historyView, HistoryView.calendar);
    // the list's actions stay in the calendar's header
    expect(find.byTooltip('Change view'), findsOneWidget);

    await show(tester, .list);
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

      await show(tester, .calendar);
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

      await show(tester, .list);
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

      await show(tester, .calendar);
      await tester.pump();
      expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
      expect(find.byType(WorkoutItem), findsNothing);
      expect(find.byKey(AppKeys.historyViewSwitch), findsOneWidget);

      await show(tester, .list);
      await tester.pump();
      expect(find.byKey(AppKeys.historyCalendar), findsNothing);
      expect(find.byType(WorkoutItem), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // the slot a view is in while the two swap: its own fade
  double faded(WidgetTester tester, HistoryView view) => tester
      .widget<FadeTransition>(
        find.descendant(of: find.byKey(ValueKey(view)), matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  testCalendar('from a scrolled list, the folded header stays folded and opens without a jump (#712)', (tester) async {
    final history = [for (final day in List.generate(12, (i) => 2 + i * 2)) finished(current, day)];
    await pumpApp(tester, size: const Size(390, 844), history: history);
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(300);
    await tester.pumpTimes();
    Finder header() => find.byType(FlexibleSpaceBar).last;
    final folded = tester.getRect(header());
    expect(folded.height, kToolbarHeight);
    final button = tester.getRect(find.byKey(AppKeys.historyViewSwitch));

    await show(tester, .calendar);
    await tester.pump();
    expect(tester.getRect(header()).height, closeTo(folded.height, 1));
    expect(tester.getRect(find.byKey(AppKeys.historyViewSwitch).last), button);
    var last = tester.getRect(header()).height;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final now = tester.getRect(header()).height;
      expect(now, greaterThanOrEqualTo(last));
      expect(now - last, lessThan(6), reason: 'the header opens, it does not jump');
      last = now;
    }
    await tester.pumpTimes();
    expect(tester.getRect(header()).height, 80);
    expect(tester.getRect(find.byKey(AppKeys.historyViewSwitch)).top, button.top);
    expect(tester.takeException(), isNull);
  });

  testCalendar('changed back mid-swap, the views turn back from where they are (#712)', (tester) async {
    await pumpApp(tester, size: const Size(390, 844), history: [finished(current, 5)]);
    await show(tester, .calendar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final leaving = faded(tester, .list);
    expect(leaving, inExclusiveRange(0, 1));

    // changed elsewhere, as from another device: the menu outlasts the swap
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.list);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // coming back, not snapped to whole or to gone
    expect(faded(tester, .list), inExclusiveRange(leaving, 1));
    expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.historyCalendar), findsNothing);
    expect(find.byType(WorkoutItem), findsOneWidget);
    expect(find.byKey(AppKeys.historyViewSwitch), findsOneWidget);
    expect(find.byTooltip('Change view'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testCalendar('changed to a third view mid-swap, it arrives over the one that was arriving (#739)', (tester) async {
    await pumpApp(tester, size: const Size(390, 844), history: [finished(current, 5)]);
    final preferences = Preferences.of(tester.element(find.byType(HistoryPage)));
    preferences.setHistoryView(.calendar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    preferences.setHistoryView(.month);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(WorkoutItem), findsNothing);
    expect(faded(tester, .calendar), inExclusiveRange(0, 1));
    await tester.pumpTimes();
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
    expect(find.byKey(AppKeys.historyViewSwitch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testCalendar('off screen mid-swap, the swap ends where it was going (#712)', (tester) async {
    await pumpApp(tester, size: const Size(390, 844), history: [finished(current, 5)]);
    await show(tester, .calendar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapByKey(AppKeys.profileStack);
    await tester.pumpTimes();
    expect(find.byType(WorkoutItem, skipOffstage: false), findsNothing);
    expect(find.byKey(AppKeys.historyCalendar, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testCalendar('the leaving view takes no taps and says nothing (#712)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, size: const Size(390, 844), history: [finished(current, 5)]);
    final card = tester.getCenter(find.byType(WorkoutItem));
    expect(find.semantics.byLabel(RegExp('Session')), findsWidgets);

    await show(tester, .calendar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byType(WorkoutItem), findsOneWidget, reason: 'still leaving');
    expect(find.semantics.byLabel(RegExp('Session')), findsNothing);
    await tester.tapAt(card);
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testCalendar("the calendar does not inherit the list's scroll (#609)", (tester) async {
    final history = [for (final day in List.generate(12, (i) => 2 + i * 2)) finished(current, day)];
    await pumpApp(tester, size: const Size(390, 844), history: history);
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    list.position.jumpTo(300);
    await tester.pumpTimes();

    await show(tester, .calendar);
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

  testCalendar('a re-tap on the tab brings the current month back, from however far (#739)', (tester) async {
    final history = [
      finished(current, 5),
      for (final back in List.generate(8, (i) => i + 1)) finished(DateTime(current.year, current.month - back), 5),
    ];
    await pumpApp(tester, size: const Size(390, 844), history: history);
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.month);
    await tester.pumpTimes();
    String named() => tester.widget<Text>(find.byKey(AppKeys.calendarMonthTitle)).data!;
    for (final _ in List.generate(5, (i) => i)) {
      await tester.tap(find.byKey(AppKeys.calendarPreviousMonth));
      await tester.pumpTimes();
    }
    expect(named(), DateFormat.yMMM('en').format(DateTime(current.year, current.month - 5)));
    await tester.tapByKey(AppKeys.historyStack);
    await tester.pumpTimes();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpTimes();
    expect(named(), DateFormat.yMMM('en').format(current));
    // and a later visit opens on the current month
    await tester.tap(find.byKey(AppKeys.calendarPreviousMonth));
    await tester.pumpTimes();
    await show(tester, .list);
    await tester.pumpTimes();
    await show(tester, .month);
    await tester.pumpTimes();
    expect(named(), DateFormat.yMMM('en').format(current));
    expect(tester.takeException(), isNull);
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
