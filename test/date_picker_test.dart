// Coverage for lib/presentation/widgets/date_picker.dart: the Material vs.
// Cupertino fork, the day-only truncation, the initial-date clamp, and
// cancelling either dialog — pumped standalone, the way duration_picker_test
// does for the same kind of platform-adaptive picker.
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/date_picker.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<({Future<DateTime?> result})> open(
    WidgetTester tester,
    TargetPlatform platform, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? title,
  }) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final result = showAdaptiveDatePicker(
      context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
    );
    await tester.pumpAndSettle();
    return (result: result);
  }

  group('iOS/macOS: the Cupertino wheel', () {
    testWidgets('confirming untouched returns the starting day, time dropped', (tester) async {
      // The default `firstDate` is today — a past date would just clamp up to
      // it, which is its own test below — so this one picks a day the
      // default window already contains.
      final future = DateTime.now().add(const Duration(days: 120));
      final expected = DateTime(future.year, future.month, future.day);
      final (:result) = await open(
        tester,
        TargetPlatform.iOS,
        initialDate: DateTime(future.year, future.month, future.day, 13, 45),
      );

      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await result, expected);
    });

    testWidgets('a title is shown above the wheel when given one', (tester) async {
      await open(tester, TargetPlatform.iOS, title: 'Due date');

      expect(find.text('Due date'), findsOneWidget);
    });

    testWidgets('no title is shown when none is given', (tester) async {
      await open(tester, TargetPlatform.iOS);

      expect(find.text('Due date'), findsNothing);
    });

    testWidgets('cancelling returns null rather than the starting date', (tester) async {
      final (:result) = await open(
        tester,
        TargetPlatform.iOS,
        initialDate: DateTime(2024, 6, 15),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await result, isNull);
    });

    testWidgets('an initial date before firstDate is clamped up to it', (tester) async {
      final (:result) = await open(
        tester,
        TargetPlatform.iOS,
        initialDate: DateTime(2020, 1, 1),
        firstDate: DateTime(2023, 1, 1),
        lastDate: DateTime(2025, 1, 1),
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await result, DateTime(2023, 1, 1));
    });

    testWidgets('an initial date after lastDate is clamped down to it', (tester) async {
      final (:result) = await open(
        tester,
        TargetPlatform.iOS,
        initialDate: DateTime(2030, 1, 1),
        firstDate: DateTime(2023, 1, 1),
        lastDate: DateTime(2025, 1, 1),
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await result, DateTime(2025, 1, 1));
    });
  });

  group('every other platform: the Material calendar', () {
    testWidgets('confirming the initial date returns that day, time dropped', (tester) async {
      // Same reasoning as the Cupertino case above: the default `firstDate`
      // is today, so a past initial date would just be its clamp test.
      final future = DateTime.now().add(const Duration(days: 120));
      final expected = DateTime(future.year, future.month, future.day);
      final (:result) = await open(
        tester,
        TargetPlatform.android,
        initialDate: DateTime(future.year, future.month, future.day, 13, 45),
      );

      expect(find.byType(CupertinoDatePicker), findsNothing);
      // Material's own picker: confirm without changing the selection.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await result, expected);
    });

    testWidgets('cancelling returns null', (tester) async {
      final (:result) = await open(
        tester,
        TargetPlatform.android,
        initialDate: DateTime(2024, 6, 15),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await result, isNull);
    });
  });
}
