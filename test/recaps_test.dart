import 'package:clock/clock.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/recaps/recaps.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/finders.dart';
import 'support/harness.dart';

/// Recaps on the profile and the monthly report (#154), through the real app:
/// "off means never built" is a claim about the whole profile.
///
/// Muffin trained twice in September 2026. The clock is fixed, because the
/// card is a thing of a month's first days.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late HeartRouter router;

  const feature = 'feature-recaps';
  final firstWeek = DateTime(2026, 10, 3, 9);
  final midMonth = DateTime(2026, 10, 18, 9);

  final monday = DateTime(2026, 9, 7, 18);
  final thursday = DateTime(2026, 9, 24, 18);
  final workouts = <RecapWorkout>[
    (id: 'muffin-1', start: monday, trained: const Duration(minutes: 50)),
    (id: 'muffin-2', start: thursday, trained: const Duration(hours: 1, minutes: 10)),
  ];

  RecapSet bench(String workout, DateTime start, double weight, int reps) {
    return (
      workoutId: workout,
      exerciseId: 'muffin-bench',
      start: start,
      category: Category.barbell,
      movement: Movement.fromJson({
        'groups': ['horizontal_press'],
      }),
      muscles: MuscleTagging.fromJson({
        'primary': {
          'ids': <String>[],
          'groups': ['chest'],
        },
      }),
      target: Target.chest,
      weight: weight,
      reps: reps,
      duration: null,
      distance: null,
    );
  }

  final sets = [
    bench('muffin-1', monday, 60, 5),
    bench('muffin-1', monday, 60, 5),
    // beats Monday's 60 × 5: records that beat something
    bench('muffin-2', thursday, 65, 5),
  ];

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    router = HeartRouter();
    stubStartup(db, api);
    when(
      db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
    ).thenAnswer((_) async => WorkoutAggregation.dummy());
  });

  void stubHistory({bool september = true}) {
    when(db.getRecapWorkouts(any, any, userId: anyNamed('userId'))).thenAnswer((invocation) async {
      final [from as DateTime, to as DateTime] = invocation.positionalArguments;
      if (!september) return const [];
      return workouts.where((workout) => !workout.start.isBefore(from) && workout.start.isBefore(to)).toList();
    });
    when(db.getRecapSets(any, any, userId: anyNamed('userId'))).thenAnswer((_) async => september ? sets : const []);
  }

  /// The app on a [width]-point window, its answer about recaps [answer]
  /// (absent: never asked).
  Future<Preferences> pumpProfile(WidgetTester tester, {String? answer, double width = 1200}) async {
    // metric, so the volume reads in the kilograms it was logged in
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'weightUnit': 'metric', feature: ?answer});

    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      router: router,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
    return Preferences.of(tester.element(find.byType(MaterialApp)));
  }

  Finder byKey(Key key) => find.byKey(key, skipOffstage: false);

  void expectNothingOfTheFeature() {
    expect(byKey(AppKeys.recapsOffer), findsNothing);
    expect(byKey(AppKeys.recapCard), findsNothing);
    expect(byKey(AppKeys.recapsEntry), findsNothing);
    expect(find.text('Recaps', skipOffstage: false), findsNothing);
  }

  /// [body] at [now], everything it pumps included.
  Future<void> at(DateTime now, Future<void> Function() body) => withClock(Clock.fixed(now), body);

  group('the offer', () {
    testWidgets('is made in a month\'s first days, after a month with training, and spends itself', (tester) async {
      await at(firstWeek, () async {
        stubHistory();
        final preferences = await pumpProfile(tester);

        expect(byKey(AppKeys.recapsOffer), findsOneWidget);
        expect(find.text('A look back at each month?', skipOffstage: false), findsOneWidget);
        expect(preferences.featureAnswer(Feature.recaps), FeatureAnswer.pending);
        expect(byKey(AppKeys.recapCard), findsNothing);
      });
    });

    testWidgets('waits for the first days of a month', (tester) async {
      await at(midMonth, () async {
        stubHistory();
        final preferences = await pumpProfile(tester);

        expectNothingOfTheFeature();
        expect(preferences.featureAnswer(Feature.recaps), FeatureAnswer.unasked);
      });
    });

    testWidgets('is not made after a month with nothing in it', (tester) async {
      await at(firstWeek, () async {
        stubHistory(september: false);
        final preferences = await pumpProfile(tester);

        expectNothingOfTheFeature();
        expect(preferences.featureAnswer(Feature.recaps), FeatureAnswer.unasked);
      });
    });

    testWidgets('yes shows last month\'s card and the way to every month', (tester) async {
      await at(firstWeek, () async {
        stubHistory();
        await pumpProfile(tester);

        await tester.ensureVisible(byKey(AppKeys.recapsAccept));
        await tester.tapByKey(AppKeys.recapsAccept);
        await tester.pumpTimes();

        expect(byKey(AppKeys.recapsOffer), findsNothing);
        expect(byKey(AppKeys.recapCard), findsOneWidget);
        expect(byKey(AppKeys.recapsEntry), findsOneWidget);
        expect(find.text('Last month · September 2026', skipOffstage: false), findsOneWidget);
        await tester.pumpTimes();
        // Thursday's 65 × 5 beat Monday's on weight, estimate and set volume
        expect(find.text('2 workouts · 2 h 0 min · 3 records', skipOffstage: false), findsOneWidget);
      });
    });

    testWidgets('no earns one notice, and closing it leaves nothing behind', (tester) async {
      await at(firstWeek, () async {
        stubHistory();
        await pumpProfile(tester);

        await tester.ensureVisible(byKey(AppKeys.recapsDecline));
        await tester.tapByKey(AppKeys.recapsDecline);
        await tester.pumpTimes(2);

        expect(byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
        await tester.tap(find.tooltip('Close'));
        await tester.pumpTimes(2);

        expectNothingOfTheFeature();
        expect(byKey(AppKeys.featureDeclinedNotice), findsNothing);
      });
    });
  });

  group('off means never built', () {
    for (final answer in ['off', 'pending']) {
      testWidgets('a device that answered "$answer" sees nothing, reads nothing, is not asked again', (tester) async {
        await at(firstWeek, () async {
          stubHistory();
          await pumpProfile(tester, answer: answer);

          expectNothingOfTheFeature();
          verifyNever(db.getRecapWorkouts(any, any, userId: anyNamed('userId')));
        });
      });
    }

    testWidgets('the switch is live both ways', (tester) async {
      await at(firstWeek, () async {
        stubHistory();
        final preferences = await pumpProfile(tester, answer: 'on');
        expect(byKey(AppKeys.recapCard), findsOneWidget);

        preferences.setFeature(Feature.recaps, on: false);
        await tester.pumpTimes(2);
        expectNothingOfTheFeature();

        preferences.setFeature(Feature.recaps, on: true);
        await tester.pumpTimes(2);
        expect(byKey(AppKeys.recapCard), findsOneWidget);
      });
    });

    testWidgets('a link to a recap lands on the profile', (tester) async {
      await at(firstWeek, () async {
        stubHistory();
        await pumpProfile(tester, answer: 'off');

        router.config.go('/profile/recaps/2026-09');
        await tester.pumpTimes();

        expect(find.byType(MonthlyReportPage), findsNothing);
        expectNothingOfTheFeature();
      });
    });
  });

  group('on', () {
    testWidgets('past the first days, the card is gone and the entry stays', (tester) async {
      await at(midMonth, () async {
        stubHistory();
        await pumpProfile(tester, answer: 'on');

        expect(byKey(AppKeys.recapCard), findsNothing);
        expect(byKey(AppKeys.recapsEntry), findsOneWidget);
      });
    });

    testWidgets('with no finished month yet, there is nothing to show', (tester) async {
      await at(firstWeek, () async {
        stubHistory(september: false);
        await pumpProfile(tester, answer: 'on');

        expectNothingOfTheFeature();
      });
    });

    testWidgets('the entry lists the months, and a month opens its report', (tester) async {
      await at(midMonth, () async {
        stubHistory();
        await pumpProfile(tester, answer: 'on');

        await tester.ensureVisible(byKey(AppKeys.recapsEntry));
        await tester.tapByKey(AppKeys.recapsEntry);
        await tester.pumpTimes();

        expect(find.byType(RecapsPage), findsOneWidget);
        expect(find.text('September 2026'), findsOneWidget);
        expect(find.text('2 workouts'), findsOneWidget);

        await tester.tap(find.text('September 2026'));
        await tester.pumpTimes();

        expect(find.byType(MonthlyReportPage), findsOneWidget);
      });
    });

    for (final width in [390.0, 1194.0]) {
      testWidgets('at ${width.toInt()}pt the card keeps a readable measure, and opens last month', (tester) async {
        await at(firstWeek, () async {
          stubHistory();
          await pumpProfile(tester, answer: 'on', width: width);

          final card = byKey(AppKeys.recapCard);
          await tester.ensureVisible(card);
          expect(tester.getSize(card).width, lessThanOrEqualTo(readableWidth));
          expect(tester.getSize(byKey(AppKeys.recapsEntry)).width, lessThanOrEqualTo(readableWidth));
          expect(tester.takeException(), isNull);

          await tester.tapByKey(AppKeys.recapCard);
          await tester.pumpTimes();

          expect(find.byType(MonthlyReportPage), findsOneWidget);
          expect(find.text('September 2026'), findsOneWidget);
        });
      });
    }

    testWidgets('the card announces where it goes', (tester) async {
      await at(firstWeek, () async {
        stubHistory();
        await pumpProfile(tester, answer: 'on');
        final handle = tester.ensureSemantics();

        expect(find.bySemanticsLabel(RegExp('Open last month\'s recap')), findsOneWidget);
        handle.dispose();
      });
    });
  });

  group('the monthly report', () {
    for (final width in [390.0, 1194.0]) {
      testWidgets('at ${width.toInt()}pt: totals, weeks, records and what the month was made of', (tester) async {
        await at(midMonth, () async {
          stubHistory();
          await pumpProfile(tester, answer: 'on', width: width);

          router.config.go('/profile/recaps/2026-09');
          await tester.pumpTimes();

          final report = find.byKey(AppKeys.monthlyReport);
          expect(report, findsOneWidget);
          Finder inReport(String text) => find.descendant(of: report, matching: find.text(text));

          expect(inReport('Workouts'), findsOneWidget);
          expect(inReport('Time trained'), findsOneWidget);
          expect(inReport('2 h 0 min'), findsOneWidget);
          expect(inReport('Weeks trained'), findsOneWidget);
          // September 2026 touches five Monday weeks; two of them trained
          expect(inReport('2 of 5'), findsOneWidget);
          expect(inReport('Total volume'), findsOneWidget);
          expect(inReport('925 kg'), findsOneWidget);
          expect(inReport('Records'), findsOneWidget);
          expect(inReport('Max weight'), findsOneWidget);
          expect(inReport('Most-trained muscles'), findsOneWidget);
          expect(inReport('Chest'), findsOneWidget);
          expect(inReport('Movement patterns'), findsOneWidget);
          expect(inReport('Most-logged exercises'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // measured and capped: a tablet's pane gets a readable column, not
          // a 1194pt row of numbers
          final list = tester.getRect(find.descendant(of: report, matching: find.byType(ListView)));
          expect(list.width, lessThanOrEqualTo(readableWidth));
          expect(list.width, lessThanOrEqualTo(width));
          // centred in what it was given
          expect((list.center.dx - width / 2).abs(), lessThan(width < 600 ? 1 : 300));
        });
      });
    }

    testWidgets('a month with nothing in it says so', (tester) async {
      await at(midMonth, () async {
        stubHistory();
        await pumpProfile(tester, answer: 'on');

        router.config.go('/profile/recaps/2026-07');
        await tester.pumpTimes();

        expect(find.text('Nothing logged this month'), findsOneWidget);
      });
    });
  });
}
