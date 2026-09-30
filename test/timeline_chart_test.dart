import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/timeline_chart.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

/// The x axis of [TimelineChart].
void main() {
  /// Every label on screen that reads as a date: `M/d` in English.
  List<String> dates(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((data) => RegExp(r'^\d{1,2}/\d{1,2}$').hasMatch(data))
        .toList();
  }

  testWidgets('two sessions on one day put its date on the axis once', (tester) async {
    // four sessions a day, three days running — the day grain, where nothing
    // is bucketed and every session is its own point. Every second point
    // labelled (the old rule, for ten points) lands on each day twice.
    final series = [
      for (final (index, day) in [28, 28, 28, 28, 29, 29, 29, 29, 30, 30].indexed)
        (at: DateTime(2026, 8, day, 7 + index), value: 20.0 + index),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: TimelineChart(series: series, initialRange: TimelineRange.month),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labels = dates(tester);
    expect(labels, isNotEmpty);
    expect(labels.toSet(), hasLength(labels.length), reason: 'a date labelled twice: $labels');
    // the most recent is always there
    expect(labels, contains('8/30'));
  });
}
