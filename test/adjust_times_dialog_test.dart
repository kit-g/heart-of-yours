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
                  onPressed: () => showAdjustTimesDialog(context, start: start, end: end, onSave: onSave),
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
}
