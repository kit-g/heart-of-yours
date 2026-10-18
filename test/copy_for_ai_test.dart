// Copy for AI (#259) on screen: the one offer in a History workout's menu,
// the switch both ways, the three sheets at a phone's width and a tablet's,
// and what reaches the clipboard. The text itself is held to its layout in
// heart_state's transcript_test.dart.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/copy_for_ai.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/exercise_detail_test_helpers.dart';

const _phone = Size(390, 844);
const _tablet = Size(1194, 834);

void main() {
  late MockWorkoutService local;
  late Workouts workouts;
  late Preferences preferences;
  late Exercises exercises;
  late List<String> clipboard;

  final bench = Exercise.fromJson({'id': 'bench', 'name': 'Bench Press', 'category': 'Barbell', 'target': 'Chest'});

  /// Finished, newest first: two this month, one three months back.
  List<Workout> history() {
    final now = DateTime.now();
    Workout finished(String id, String name, DateTime start, double weight) {
      return Workout.fromJson({
        'id': id,
        'name': name,
        'start': start.toIso8601String(),
        'end': start.add(const Duration(hours: 1)).toIso8601String(),
        'exercises': [
          {
            'id': '$id-e',
            'order': 0,
            'exercise': bench.toMap(),
            'sets': [
              {'id': '$id-s', 'weight': weight, 'reps': 5, 'completed': 1, 'rpe': 8},
            ],
          },
        ],
        'synced': 1,
      });
    }

    return [
      finished('w3', 'Muffin push', now.subtract(const Duration(days: 2)), 85),
      finished('w2', 'Push day', now.subtract(const Duration(days: 9)), 82.5),
      finished('w1', 'Old push', now.subtract(const Duration(days: 100)), 70),
    ];
  }

  Future<void> start({Map<String, Object> stored = const {}}) async {
    // Programs is on by default and would read providers this fixture skips
    SharedPreferences.setMockInitialValues({'feature-programs': 'off', ...stored});
    preferences = Preferences();
    await preferences.init();
    local = MockWorkoutService();
    when(local.getWorkoutHistory(any)).thenAnswer((_) async => history());
    workouts = Workouts(
      service: local,
      remoteService: MockRemoteWorkoutService(),
      remote: RemoteAccess(allowed: false),
    )..userId = 'u1';
    await workouts.initHistory();
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
      remote: RemoteAccess(allowed: false),
    );
  }

  setUp(() {
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
        return null;
      },
    );
  });

  Future<void> pump(WidgetTester tester, Widget child, {Size size = _phone}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
  }

  L l(WidgetTester tester) => L.of(tester.element(find.byType(Scaffold).first));

  group('the offer', () {
    testWidgets('lives in a workout\'s menu; seeing it spends it, and it stays for the session', (tester) async {
      await start();
      await pump(tester, WorkoutItem(workout: workouts.history.first));

      await openMenu(tester);
      expect(find.text(l(tester).copyForAi), findsOneWidget);
      expect(preferences.featureAnswer(.copyForAi), FeatureAnswer.pending);

      // still there for the rest of the session
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text(l(tester).copyForAi), findsOneWidget);
    });

    testWidgets('left unanswered, it is gone from the next launch on', (tester) async {
      await start(stored: {'feature-copyForAi': 'pending'});
      await pump(tester, WorkoutItem(workout: workouts.history.first));

      await openMenu(tester);
      expect(find.text(l(tester).copyForAi), findsNothing);
    });

    testWidgets('yes turns it on and goes straight to the workout\'s text', (tester) async {
      await start();
      final workout = workouts.history.firstWhere((each) => each.id == 'w3');
      await pump(tester, WorkoutItem(workout: workout));

      await openMenu(tester);
      await tester.tap(find.text(l(tester).copyForAi));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.copyForAiOffer), findsOneWidget);
      // sized to its words, not stretched to the sheet's height (9/16 of the
      // screen, ~474 here): a card of white space under two buttons
      expect(tester.getSize(find.byKey(AppKeys.copyForAiOffer)).height, lessThan(400));

      await tester.tap(find.byKey(AppKeys.copyForAiAccept));
      await tester.pumpAndSettle();

      expect(preferences.isOn(.copyForAi), isTrue);
      expect(find.byKey(AppKeys.copyForAiSheet), findsOneWidget);
      final preview = find.descendant(of: find.byKey(AppKeys.copyForAiPreview), matching: find.byType(Text));
      final text = tester.widget<Text>(preview).data!;
      expect(text, startsWith(l(tester).aiWorkoutIntro));
      expect(text, contains('Muffin push'));
      expect(text, contains('85 × 5, RPE 8'));
    });

    testWidgets('no earns the one notice, and the item goes', (tester) async {
      await start();
      await pump(tester, WorkoutItem(workout: workouts.history.first));

      await openMenu(tester);
      await tester.tap(find.text(l(tester).copyForAi));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.copyForAiDecline));
      await tester.pump();

      expect(preferences.featureAnswer(.copyForAi), FeatureAnswer.off);
      expect(find.text(l(tester).featureDeclinedNotice), findsOneWidget);
      expect(preferences.owesDeclineNotice(.copyForAi), isFalse);

      await tester.pumpAndSettle(const Duration(seconds: 5));
      await openMenu(tester);
      expect(find.text(l(tester).copyForAi), findsNothing);
    });

    testWidgets('waving the offer away is a no', (tester) async {
      await start();
      await pump(tester, WorkoutItem(workout: workouts.history.first));

      await openMenu(tester);
      await tester.tap(find.text(l(tester).copyForAi));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(preferences.featureAnswer(.copyForAi), FeatureAnswer.off);
    });
  });

  group('the switch', () {
    testWidgets('off, the menu is as it was before the feature', (tester) async {
      await start(stored: {'feature-copyForAi': 'off'});
      await pump(tester, WorkoutItem(workout: workouts.history.first));

      await openMenu(tester);
      expect(find.text(l(tester).copyForAi), findsNothing);
      expect(find.text(l(tester).delete), findsOneWidget);
    });

    testWidgets('flipped on in Settings, the item is there without an ask', (tester) async {
      await start(stored: {'feature-copyForAi': 'off'});
      await pump(tester, WorkoutItem(workout: workouts.history.first));
      preferences.setFeature(.copyForAi, on: true);
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.text(l(tester).copyForAi));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.copyForAiOffer), findsNothing);
      expect(find.byKey(AppKeys.copyForAiSheet), findsOneWidget);
    });
  });

  group('the sheet', () {
    Widget opener(Future<void> Function(BuildContext) open) {
      return Builder(
        builder: (context) => TextButton(onPressed: () => open(context), child: const Text('open')),
      );
    }

    for (final (name, size) in [('phone', _phone), ('tablet', _tablet)]) {
      testWidgets('a period, at a $name\'s width: four weeks by default, a month a step away, capped', (tester) async {
        await start(stored: {'feature-copyForAi': 'on'});
        await pump(tester, opener(copyPeriodForAi), size: size);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final sheet = tester.getSize(find.byKey(AppKeys.copyForAiSheet));
        expect(sheet.width, lessThanOrEqualTo(560));
        expect(tester.takeException(), isNull);

        Text preview() {
          return tester.widget<Text>(
            find.descendant(of: find.byKey(AppKeys.copyForAiPreview), matching: find.byType(Text)),
          );
        }

        // the last four weeks: the two recent ones, not the old one
        expect(preview().data, contains('Muffin push'));
        expect(preview().data, contains('Push day'));
        expect(preview().data, isNot(contains('Old push')));
        // no program running, so no program to pick
        expect(find.text(l(tester).copyForAiProgram), findsNothing);

        await tester.tap(find.text(l(tester).copyForAiMonth));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(l(tester).copyForAiEarlierMonth).hitTestable());
        await tester.pumpAndSettle();
        // a month or so back: whichever it is, the recent ones are not in it
        expect(find.textContaining('Muffin push'), findsNothing);

        await tester.tap(find.text(l(tester).copyForAiLastFourWeeks));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AppKeys.copyForAiCopy));
        await tester.pumpAndSettle();

        expect(clipboard, hasLength(1));
        expect(clipboard.single, contains('Muffin push'));
        expect(find.text(l(tester).copyForAiCopied), findsOneWidget);
        expect(find.byKey(AppKeys.copyForAiSheet), findsNothing);
      });
    }

    testWidgets('every control on the sheet announces itself and is big enough to hit', (tester) async {
      final handle = tester.ensureSemantics();
      await start(stored: {'feature-copyForAi': 'on'});
      await pump(tester, opener(copyPeriodForAi));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l(tester).copyForAiMonth));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('a month with nothing in it says so, with nothing to copy', (tester) async {
      await start(stored: {'feature-copyForAi': 'on'});
      await pump(tester, opener(copyPeriodForAi));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l(tester).copyForAiMonth));
      await tester.pumpAndSettle();
      // step back to a month between the old workout and the recent ones
      for (final _ in Iterable.generate(2)) {
        await tester.tap(find.byTooltip(l(tester).copyForAiEarlierMonth));
        await tester.pumpAndSettle();
      }
      // two months back: after the old workout (100 days ago), before the rest
      expect(find.text(l(tester).copyForAiEmpty), findsOneWidget);
      expect(find.byKey(AppKeys.copyForAiCopy), findsNothing);
      expect(find.byKey(AppKeys.copyForAiShare), findsNothing);
    });

    testWidgets('one exercise\'s history, from its tab while on; absent while off', (tester) async {
      final state = await buildExerciseDetailState();
      when(
        state.exerciseService.getExerciseHistory(any, any, pageSize: anyNamed('pageSize'), anchor: anyNamed('anchor')),
      ).thenAnswer(
        (_) async => [
          TestExerciseAct(workoutId: 'w3', workoutName: 'Muffin push', start: DateTime(2026, 9, 10), sets: []),
        ],
      );
      when(state.workoutService.getWorkoutHistory(any)).thenAnswer((_) async => history());
      await state.workouts.initHistory();

      await pumpExerciseDetail(tester, bench, initialTab: 'history', state: state);
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.copyForAiExercise), findsNothing);

      state.preferences.setFeature(.copyForAi, on: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.copyForAiExercise));
      await tester.pumpAndSettle();

      final text = tester
          .widget<Text>(find.descendant(of: find.byKey(AppKeys.copyForAiPreview), matching: find.byType(Text)))
          .data!;
      expect(text, startsWith('My history of Bench Press'));
      expect(text, contains('3 sessions'));
      expect(text, contains('Old push'));
    });
  });
}
