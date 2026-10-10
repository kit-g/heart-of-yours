import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/countdown.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// One rest countdown at a time, owned by the exercise whose set started it.
/// Two exercises with rest timers used to share the single countdown: the
/// second set's dialog silently showed the first timer's remaining time, and
/// both exercise headers animated the same ring.
void main() {
  late Alarms alarms;

  setUp(() => alarms = Alarms());

  Future<void> pumpCountdown(WidgetTester tester, {required int total, required String exerciseId}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<Alarms>.value(
        value: alarms,
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: Countdown(
              total: total,
              exerciseId: exerciseId,
              scheduleNotification: (_) {},
            ),
          ),
        ),
      ),
    );
    // afterFirstLayout runs in a post-frame callback
    await tester.pump();
  }

  testWidgets('a set on another exercise takes over the countdown', (tester) async {
    alarms.startActiveExerciseTimer(300, exerciseId: 'bench');

    await pumpCountdown(tester, total: 60, exerciseId: 'squat');

    expect(alarms.activeExerciseId, 'squat');
    expect(alarms.activeExerciseTotal, 60);

    // the binding checks for pending timers before tearDown callbacks run
    alarms.stopActiveExerciseTimer();
  });

  testWidgets('reopening the countdown for its own exercise resumes it', (tester) async {
    alarms.startActiveExerciseTimer(300, exerciseId: 'bench');
    final running = alarms.remainsInActiveExercise;

    await pumpCountdown(tester, total: 300, exerciseId: 'bench');

    expect(alarms.activeExerciseId, 'bench');
    expect(identical(alarms.remainsInActiveExercise, running), isTrue, reason: 'must not restart');

    alarms.stopActiveExerciseTimer();
  });

  testWidgets('with no countdown running, one starts for the set just completed', (tester) async {
    await pumpCountdown(tester, total: 90, exerciseId: 'bench');

    expect(alarms.activeExerciseId, 'bench');
    expect(alarms.activeExerciseTotal, 90);

    alarms.stopActiveExerciseTimer();
  });

  testWidgets('a rest skipped from elsewhere closes the dialog instead of leaving it at 00:00', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<Alarms>.value(
        value: alarms,
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCountdownDialog(context, 90, exerciseId: 'bench', scheduleNotification: (_) {}),
                child: const Text('rest'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('rest'));
    await tester.pumpAndSettle();
    expect(find.byType(Countdown), findsOneWidget);

    // the notification's Skip, applied by the phone
    alarms.stopActiveExerciseTimer();
    await tester.pumpAndSettle();

    expect(find.byType(Countdown), findsNothing);
    // and only the dialog went
    expect(find.text('rest'), findsOneWidget);
  });

  testWidgets('its own Skip closes it once, not the page under it', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<Alarms>.value(
        value: alarms,
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCountdownDialog(context, 90, exerciseId: 'bench', scheduleNotification: (_) {}),
                child: const Text('rest'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('rest'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(Countdown), findsNothing);
    expect(find.text('rest'), findsOneWidget);
  });
}
