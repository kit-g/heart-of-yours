import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/program_progress.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {double width = 320}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: .topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  List<double> fills(WidgetTester tester) {
    return tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((each) => each.widthFactor!)
        .toList();
  }

  testWidgets('the weeks behind are filled, the one under way as far as it is done', (tester) async {
    await pump(tester, const ProgramWeeksBar(week: 3, weeks: 5, done: .5));
    expect(fills(tester), [1, 1, .5, 0, 0]);
    expect(find.bySemanticsLabel(RegExp('Week 3 of 5')), findsWidgets);
  });

  testWidgets('weeks too many to tell apart are one bar', (tester) async {
    await pump(tester, const ProgramWeeksBar(week: 27, weeks: 52, done: 0), width: 200);
    expect(fills(tester), [.5]);
  });

  testWidgets('a week past the last is a full bar, not an overflow', (tester) async {
    await pump(tester, const ProgramWeeksBar(week: 9, weeks: 8, done: 1));
    expect(fills(tester), List.filled(8, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a ring each, ticked as they are done, and one more past the target', (tester) async {
    await pump(tester, const WeekCount(done: 1, target: 3));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1 of 3 this week')), findsWidgets);

    await pump(tester, const WeekCount(done: 3, target: 2));
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
  });

  testWidgets('the words are there on a long press', (tester) async {
    await pump(tester, const WeekCount(done: 2, target: 2));
    await tester.longPress(find.byType(WeekCount));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 this week'), findsOneWidget);
  });
}
