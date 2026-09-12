import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';
import 'package:heart/presentation/widgets/keys.dart';
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<Workouts>.value(
        value: workouts,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const Scaffold(body: HistoryCalendar()),
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
    final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
    scroll.jumpTo(40);
    await tester.pump();
    final month = find.byKey(ValueKey(key(current)));
    final position = tester.getTopLeft(month);
    workouts.rows[key(before)] = [workout(before, 5)];
    workouts.notifyListeners();
    await tester.pump();
    expect(scroll.offset, 40);
    expect(tester.getTopLeft(month), position);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fetches full workout before stacking editor; discard preserves calendar state', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    final full = workout(current, 5);
    full.add(Exercise(name: 'Bench Press', category: .barbell, target: .chest));
    full.finish(full.start.add(const Duration(hours: 1)));
    final shallow = Workout.fromJson(full.toMap()..['exercises'] = <Object>[]);
    final older = workout(before, 6)..finish(before.add(const Duration(hours: 1)));
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => [shallow, older]);
    final fetched = Completer<Workout?>();
    when(db.getWorkout(any, full.id)).thenAnswer((_) => fetched.future);
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
    await tester.tap(find.byTooltip('Calendar'));
    await tester.pumpTimes();
    final calendarState = tester.state(find.byType(HistoryCalendar));
    final list = find.descendant(of: find.byType(HistoryCalendar), matching: find.byType(ListView));
    final scroll = tester.widget<ListView>(list).controller!;
    scroll.jumpTo(40);
    await tester.pumpTimes();
    final offset = scroll.offset;
    final label = '${DateFormat.yMMMMEEEEd('en').format(full.start)}, Edit Workout';
    await tester.tap(find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label));
    await tester.pumpTimes();
    verify(db.getWorkout(any, full.id)).called(1);
    expect(find.byType(WorkoutEditor), findsNothing);
    fetched.complete(full);
    await tester.pumpTimes();
    final editor = tester.widget<WorkoutEditor>(find.byType(WorkoutEditor));
    expect(editor.copy.first.exercise.name, 'Bench Press');
    expect(
      find.descendant(of: find.byType(HistoryCalendar), matching: find.byType(CircularProgressIndicator)),
      findsNothing,
    );
    expect(identical(editor.copy, full), isFalse);
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byType(AppBarTextField), matching: find.byType(TextField)),
      'Changed name',
    );
    await tester.pumpTimes();
    expect(editor.copy.name, 'Changed name');
    final l = L.of(tester.element(find.byType(WorkoutEditor)));
    await tester.tap(find.byKey(AppKeys.closeDetail));
    await tester.pumpTimes();
    expect(find.text(l.quitEditing), findsOneWidget);
    await tester.tap(find.text(l.stayHere));
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsOneWidget);
    // System back follows PopScope's discard path too.
    final navigator = Navigator.of(tester.element(find.byType(WorkoutEditor)));
    unawaited(navigator.maybePop());
    await tester.pumpTimes();
    await tester.tap(find.text(l.quitPage));
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsNothing);
    expect(tester.state(find.byType(HistoryCalendar)), same(calendarState));
    expect(scroll.offset, offset);
    expect(full.name, 'Session');
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(834, 1194), const Size(1194, 834)]) {
    testWidgets('calendar is capped and fits $size', (tester) async {
      await pump(tester, _Workouts(), size: size);
      final material = find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first;
      expect(tester.getSize(material).width, lessThanOrEqualTo(400));
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
}
