// The "Adjust Start/End Time" dialog, pumped directly.
//
// It is a standalone widget (not part of the `workout.dart` private library),
// so it needs no router or providers — just a MaterialApp for localizations
// and a theme whose `platform` picks the Cupertino wheel or the Material
// popup pickers, the same fork the widget itself switches on.
import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/workout/adjust_times_dialog.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' show WorkoutPause;
import 'package:material_ui/material_ui.dart';

void main() {
  final start = DateTime(2026, 6, 1, 9);
  final end = DateTime(2026, 6, 1, 10, 30);

  Future<void> pump(
    WidgetTester tester, {
    required DateTime start,
    required DateTime? end,
    required Future<void> Function(DateTime start, DateTime? end) onSave,
    TargetPlatform platform = TargetPlatform.android,
    List<WorkoutPause> pauses = const [],
    bool needsLength = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: ThemeData(platform: platform),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAdjustTimesDialog(
                    context,
                    start: start,
                    end: end,
                    onSave: onSave,
                    pauses: pauses,
                    needsLength: needsLength,
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('shows the start and end rows with their duration', (tester) async {
    await pump(tester, start: start, end: end, onSave: (_, _) async {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Adjust Start/End Time'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('End time'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('1:30:00'), findsOneWidget);
  });

  testWidgets('the duration leaves out the pauses that fall inside the times (#134)', (tester) async {
    await pump(
      tester,
      start: start,
      end: end,
      onSave: (_, _) async {},
      pauses: [
        WorkoutPause(start: start.add(const Duration(minutes: 10)), end: start.add(const Duration(minutes: 20))),
        // runs past the end: only the part inside counts
        WorkoutPause(start: end.subtract(const Duration(minutes: 5)), end: end.add(const Duration(minutes: 30))),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('1:15:00'), findsOneWidget);
  });

  testWidgets('hides the end row and duration when the workout is still open', (tester) async {
    await pump(tester, start: start, end: null, onSave: (_, _) async {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('End time'), findsNothing);
    expect(find.text('Duration'), findsNothing);
  });

  testWidgets('the close button pops without saving', (tester) async {
    var saved = false;
    await pump(
      tester,
      start: start,
      end: end,
      onSave: (_, _) async {
        saved = true;
      },
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Adjust Start/End Time'), findsNothing);
    expect(saved, isFalse);
  });

  testWidgets('rejects an end before the start, without saving or closing', (tester) async {
    var saved = false;
    // constructed already inverted: the fastest way to exercise the guard in
    // `_save` without having to drive a picker to move a valid pair out of order
    await pump(
      tester,
      start: end,
      end: start,
      onSave: (_, _) async {
        saved = true;
      },
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("End time can't be before the start time."), findsOneWidget);
    expect(find.text('Adjust Start/End Time'), findsOneWidget);
    expect(saved, isFalse);
  });

  testWidgets('save batches both fields into one call and closes', (tester) async {
    DateTime? savedStart;
    DateTime? savedEnd;
    await pump(
      tester,
      start: start,
      end: end,
      onSave: (s, e) async {
        savedStart = s;
        savedEnd = e;
      },
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedStart, start);
    expect(savedEnd, end);
    expect(find.text('Adjust Start/End Time'), findsNothing);
  });

  testWidgets('shows a spinner while saving and disables closing meanwhile', (tester) async {
    final saving = Completer<void>();
    await pump(
      tester,
      start: start,
      end: end,
      onSave: (_, _) => saving.future,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    final close = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close_rounded));
    expect(close.onPressed, isNull);

    saving.complete();
    await tester.pumpAndSettle();

    expect(find.text('Adjust Start/End Time'), findsNothing);
  });

  testWidgets('iOS unfolds the inline wheel for the tapped row, one at a time', (tester) async {
    await pump(tester, start: start, end: end, onSave: (_, _) async {}, platform: TargetPlatform.iOS);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsNothing);

    await tester.tap(find.text('Start time'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    // opening the end picker folds the start one back up: only one open at once
    await tester.tap(find.text('End time'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    // tapping the open row again folds it back
    await tester.tap(find.text('End time'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('android taps the start row through the Material date and time popups', (tester) async {
    await pump(tester, start: start, end: end, onSave: (_, _) async {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start time'));
    await tester.pumpAndSettle();

    // the date popup: cancelling exercises `_pickMaterial`'s null-date bailout
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // the dialog is still up, unharmed, and the value did not change
    expect(find.text('Adjust Start/End Time'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
  });

  testWidgets('logging after the fact, moving the start carries the end along (#530)', (tester) async {
    DateTime? savedStart;
    DateTime? savedEnd;
    await pump(
      tester,
      start: start,
      end: end,
      needsLength: true,
      platform: TargetPlatform.iOS,
      onSave: (s, e) async {
        savedStart = s;
        savedEnd = e;
      },
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start time'));
    await tester.pumpAndSettle();
    final earlier = start.subtract(const Duration(days: 1));
    tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).onDateTimeChanged(earlier);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedStart, earlier);
    expect(savedEnd, end.subtract(const Duration(days: 1)), reason: 'the same length, a day earlier');
  });

  group('"When was it?" (#738)', () {
    /// The dialog for a workout of the last hour, [row]'s wheel open.
    Future<({DateTime Function() start, DateTime Function() end})> open(
      WidgetTester tester,
      String row, {
      bool needsLength = true,
    }) async {
      late DateTime savedStart;
      late DateTime savedEnd;
      final now = DateTime.now();
      await pump(
        tester,
        start: now.subtract(const Duration(hours: 1)),
        end: now,
        needsLength: needsLength,
        platform: .iOS,
        onSave: (s, e) async => (savedStart, savedEnd) = (s, e!),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
      return (start: () => savedStart, end: () => savedEnd);
    }

    Future<void> scroll(WidgetTester tester, double days) async {
      await tester.timedDrag(
        find.byType(CupertinoPicker).first,
        Offset(0, days),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the end scrolled to a past day stays there, and takes the start along', (tester) async {
      final saved = await open(tester, 'End time');
      await scroll(tester, 96);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(DateTime.now().difference(saved.end()).inDays, greaterThanOrEqualTo(1));
      expect(saved.end().difference(saved.start()), const Duration(hours: 1));
    });

    testWidgets('the end scrolled back and forward again ends where it would have anyway', (tester) async {
      final saved = await open(tester, 'End time');
      final wheel = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      final end = wheel.initialDateTime;
      for (final days in [1, 2, 3, 2, 1, 0]) {
        wheel.onDateTimeChanged(end.subtract(Duration(days: days)));
      }
      for (final minutes in [10, 59, 61, 180, 61, 0]) {
        wheel.onDateTimeChanged(end.subtract(Duration(minutes: minutes)));
      }
      wheel.onDateTimeChanged(end.subtract(const Duration(days: 1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved.end(), end.subtract(const Duration(days: 1)));
      expect(saved.start(), end.subtract(const Duration(days: 1, hours: 1)));
    });

    testWidgets('from a past day, the end moved to today takes the start along too', (tester) async {
      final saved = await open(tester, 'End time');
      var wheel = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      final end = wheel.initialDateTime;
      wheel.onDateTimeChanged(end.subtract(const Duration(days: 2)));
      await tester.tap(find.text('End time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End time'));
      await tester.pumpAndSettle();
      wheel = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      wheel.onDateTimeChanged(end);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved.end().difference(saved.start()), const Duration(hours: 1));
    });

    testWidgets('a longer and a shorter workout are still the end moved', (tester) async {
      final saved = await open(tester, 'End time');
      final wheel = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      wheel.onDateTimeChanged(wheel.initialDateTime.subtract(const Duration(minutes: 20)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved.end().difference(saved.start()), const Duration(minutes: 40));
    });

    testWidgets("the start goes no later than leaves the workout's length before now", (tester) async {
      await open(tester, 'Start time');
      final wheel = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      expect(DateTime.now().difference(wheel.maximumDate!).inMinutes, inInclusiveRange(59, 61));
    });

    testWidgets('a workout of no time is refused', (tester) async {
      await pump(tester, start: start, end: start, needsLength: true, onSave: (_, _) async => fail('saved'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('The end has to come after the start.'), findsOneWidget);
    });

    testWidgets('on Android, the same day and no to a new time change nothing, to the second', (tester) async {
      final exact = DateTime(2026, 6, 1, 9, 0, 37);
      DateTime? savedStart;
      await pump(tester, start: exact, end: end, onSave: (s, _) async => savedStart = s);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(savedStart, exact);
    });

    testWidgets('the start scrolled back can be scrolled forward again', (tester) async {
      final saved = await open(tester, 'Start time');
      await scroll(tester, 400);
      await scroll(tester, -96);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final forward = saved.start();

      await tester.pumpWidget(const SizedBox());
      final back = await open(tester, 'Start time');
      await scroll(tester, 400);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(forward.isAfter(back.start()), isTrue);
      expect(saved.end().difference(forward), const Duration(hours: 1));
    });

    testWidgets("a finished workout's end still can't go before its start", (tester) async {
      final saved = await open(tester, 'End time', needsLength: false);
      await scroll(tester, 96);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved.end().isBefore(saved.start()), isFalse);
      expect(DateTime.now().difference(saved.start()).inMinutes, inInclusiveRange(59, 61), reason: 'not moved');
    });

    testWidgets('on Android, no to a new time keeps the day picked', (tester) async {
      DateTime? savedStart;
      await pump(
        tester,
        start: start,
        end: end,
        needsLength: true,
        onSave: (s, _) async => savedStart = s,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start time'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(savedStart, DateTime(2026, 5, 15, 9));
    });
  });
}
