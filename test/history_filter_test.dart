import 'dart:async';

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

  final now = DateTime.now();
  final chestDay = finished('Chest day', bench, DateTime(now.year, now.month, 1, 9));
  final legDay = finished('Leg day', squat, DateTime(now.year, now.month, 1, 18));
  final backDay = finished('Back day', own, DateTime(now.year, now.month - 1, 3, 9));

  Future<MockApi> pumpApp(
    WidgetTester tester, {
    required List<Workout> history,
    Size size = const Size(390, 844),
    bool account = false,
    void Function(MockApi api)? stub,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => history);
    stub?.call(api);
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

  testWidgets('the list shows the workouts that trained any group picked (#610)', (tester) async {
    await pumpApp(tester, history: [chestDay, legDay, backDay]);
    expect(cards(tester), hasLength(3));
    expect(find.byKey(AppKeys.historyFilterChips), findsNothing);

    await pick(tester, .legs);
    expect(cards(tester), ['Leg day']);
    expect(find.byKey(AppKeys.historyFilterChips), findsOneWidget);
    // a month with nothing in the filter has no heading either
    final previous = DateTime(now.year, now.month - 1);
    expect(find.text(DateFormat.yMMMM('en').format(previous).toUpperCase()), findsNothing);

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

  testWidgets('secondary muscles do not count: a bench session is no arm day (#610)', (tester) async {
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

  testWidgets('with the whole history here, a group none of it trained is greyed (#610)', (tester) async {
    await pumpApp(tester, history: [chestDay, legDay]);
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

  testWidgets('the calendar marks only the days the filter lets through (#610)', (tester) async {
    final semantics = tester.ensureSemantics();
    final other = finished('Chest again', bench, DateTime(now.year, now.month, 2, 9));
    await pumpApp(tester, history: [chestDay, legDay, other], size: const Size(1194, 834));
    final context = tester.element(find.byType(HistoryPage));
    Preferences.of(context).setHistoryView(.calendar);
    HistoryFilter.of(context).toggle(.legs);
    await tester.pumpTimes();

    String label(DateTime day) => DateFormat.yMMMMEEEEd('en').format(day);
    Finder day(String label) =>
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

    // the 1st holds two, one of them legs: one mark, and it opens that one
    expect(day('${label(chestDay.start)}, edit workout'), findsOneWidget);
    // the 2nd trained only chest: plain, and it does nothing — it is not empty
    final second = tester.widget<Semantics>(day(label(other.start)));
    expect(second.properties.onTap, isNull);
    expect(find.byKey(AppKeys.historyFilterChips), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('while older pages are still to come, the filter pages them in and looks there too (#610)', (
    tester,
  ) async {
    final older = finished('Old leg day', squat, DateTime(now.year - 1, 3, 4, 9));
    final page = Completer<Iterable<Workout>>();
    // enough that the list's own tail is never in sight, so nothing pages but the filter
    final recent = [
      for (final day in List.generate(12, (index) => index + 1))
        finished('Chest $day', bench, DateTime(now.year, now.month, 1, day)),
    ];
    final api = await pumpApp(
      tester,
      history: recent,
      account: true,
      // the device holds a prefix: the server says there is more behind it
      stub: (api) => when(api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since'))).thenAnswer(
        (invocation) async => switch (invocation.namedArguments[#since]) {
          null => Page(items: recent.reversed.toList(), hasMore: true),
          _ => page.future,
        },
      ),
    );
    final context = tester.element(find.byType(HistoryPage));
    final workouts = Workouts.of(context);
    expect(workouts.hasMoreHistory, isTrue);

    HistoryFilter.of(context).toggle(.legs);
    await tester.pumpTimes();
    // nothing in what is here, and more to look through: no "nothing matches" yet
    expect(find.text('Looking through older workouts…'), findsOneWidget);
    expect(find.byKey(AppKeys.historyFilterEmpty), findsNothing);

    page.complete(Page(items: [older], hasMore: false));
    await tester.pumpTimes();

    verify(api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: recent.first.id)).called(1);
    expect(workouts.hasMoreHistory, isFalse);
    expect(cards(tester), ['Old leg day']);
    expect(tester.takeException(), isNull);
  });
}
