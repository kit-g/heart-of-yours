import 'dart:ui' show Tristate;

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
  final now = DateTime.now();
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'firstWeekday': ?firstWeekday});
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
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('one badge per completed day; empty days have no action', (tester) async {
    final semantics = tester.ensureSemantics();

    final workouts = _Workouts()..rows[key(current)] = [workout(current, 5), workout(current, 5), workout(current, 8)];
    await pump(tester, workouts);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    final marked = tester.getSemantics(
      find.bySemanticsLabel('${DateFormat.yMMMMEEEEd('en').format(DateTime(now.year, now.month, 5))}, Edit Workout'),
    );
    expect(marked.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    final empty = tester.getSemantics(
      find.bySemanticsLabel(DateFormat.yMMMMEEEEd('en').format(DateTime(now.year, now.month, 6))),
    );
    expect(empty.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('a day of several sessions opens the newest', (tester) async {
    final earlier = Workout(name: 'Morning')..start = DateTime(current.year, current.month, 5, 7);
    final later = Workout(name: 'Evening')..start = DateTime(current.year, current.month, 5, 19);
    final opened = <Workout>[];
    // newest first, as byMonth has them
    await pump(tester, _Workouts()..rows[key(current)] = [later, earlier], onTapWorkout: opened.add);
    await tester.tap(find.byIcon(Icons.check));
    expect(opened.single.name, 'Evening');
  });

  testWidgets('a trained day is marked even where it opens nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, _Workouts()..rows[key(current)] = [workout(current, 5)], opens: false);
    expect(find.byIcon(Icons.check), findsOneWidget);
    final day = tester.getSemantics(
      find.bySemanticsLabel(DateFormat.yMMMMEEEEd('en').format(DateTime(now.year, now.month, 5))),
    );
    expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('empty intervening month renders; scrolling stops at loaded window', (tester) async {
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

  testWidgets('oldest month requests once, never while loading or erroring; retry is explicit', (tester) async {
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

  testWidgets('an older page extends upward without moving the visible months', (tester) async {
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

  Future<MockLocalDatabase> pumpApp(WidgetTester tester, {required Size size, required List<Workout> history}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(pastOnboarding());
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
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

  testWidgets('the switch turns History into the calendar and back, and History opens on the last one (#609)', (
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

  testWidgets("the calendar does not inherit the list's scroll (#609)", (tester) async {
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

  testWidgets('edits discarded in a workout opened from the calendar never reach History (#609)', (tester) async {
    final session = finished(current, 5);
    await pumpApp(tester, size: const Size(1194, 834), history: [session]);
    final context = tester.element(find.byType(HistoryPage));
    Preferences.of(context).setHistoryView(.calendar);
    await tester.pumpTimes();
    await tester.tap(day('${DateFormat.yMMMMEEEEd('en').format(session.start)}, Edit Workout'));
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

  testWidgets('a marked day opens its workout in the detail pane, and marks itself (#609)', (tester) async {
    final semantics = tester.ensureSemantics();
    final session = finished(current, 5);
    await pumpApp(tester, size: const Size(1194, 834), history: [session]);
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.calendar);
    await tester.pumpTimes();

    final label = '${DateFormat.yMMMMEEEEd('en').format(session.start)}, Edit Workout';
    await tester.tap(day(label));
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsOneWidget);
    // the calendar stays where it was, in the master pane beside it
    expect(find.byKey(AppKeys.historyCalendar), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(WorkoutEditor)).dx,
      greaterThan(tester.getTopRight(find.byKey(AppKeys.historyCalendar)).dx),
    );
    expect(tester.getSemantics(day(label)).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('a marked day on a phone pushes its workout over the calendar (#609)', (tester) async {
    final session = finished(current, 5);
    await pumpApp(tester, size: const Size(390, 844), history: [session]);
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.calendar);
    await tester.pumpTimes();
    final semantics = tester.ensureSemantics();
    await tester.tap(day('${DateFormat.yMMMMEEEEd('en').format(session.start)}, Edit Workout'));
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final size in [const Size(390, 844), const Size(834, 1194), const Size(1194, 834)]) {
    testWidgets('calendar is capped and fits $size', (tester) async {
      await pump(tester, _Workouts(), size: size);
      final months = find.descendant(of: find.byType(HistoryCalendar), matching: find.byType(ListView));
      expect(tester.getSize(months).width, lessThanOrEqualTo(calendarWidth));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Russian starts Monday, English starts Sunday', (tester) async {
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

  testWidgets("the user's first day wins over the locale's (#339)", (tester) async {
    final semantics = tester.ensureSemantics();

    await pump(tester, _Workouts(), firstWeekday: DateTime.saturday);
    final saturday = tester.getTopLeft(find.bySemanticsLabel('Saturday')).dx;
    for (final day in ['Sunday', 'Monday', 'Friday']) {
      expect(saturday, lessThan(tester.getTopLeft(find.bySemanticsLabel(day)).dx), reason: day);
    }
    semantics.dispose();
  });
}
