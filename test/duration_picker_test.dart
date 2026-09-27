import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/duration_picker.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

/// Set timer returns what the wheel shows. It used to read its starting value
/// as a wheel row, so confirming 2:30 untouched saved 12:35 — and on Android
/// the wheel never reported back at all, so turning it changed nothing.
void main() {
  /// Opens the picker; the record keeps its result pending rather than letting
  /// `await` flatten it into waiting for the dialog to close.
  Future<({Future<int?> result})> open(WidgetTester tester, TargetPlatform platform, {int? initialValue}) async {
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
    final result = showDurationPicker(context, initialValue: initialValue);
    await tester.pumpAndSettle();
    return (result: result);
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group(platform.name, () {
      testWidgets('confirming untouched returns the starting value', (tester) async {
        final (:result) = await open(tester, platform, initialValue: 150);

        await tester.tap(find.text('Set timer'));
        await tester.pumpAndSettle();

        expect(await result, 150);
      });

      testWidgets('confirming with no timer yet returns the first row', (tester) async {
        final (:result) = await open(tester, platform);

        await tester.tap(find.text('Set timer'));
        await tester.pumpAndSettle();

        expect(await result, 5);
      });

      testWidgets('confirming after a turn returns the row it stopped on', (tester) async {
        final (:result) = await open(tester, platform, initialValue: 150);

        // two rows of 40pt down the wheel: 2:30 → 2:40
        await tester.drag(find.text('02:30'), const Offset(0, -80));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set timer'));
        await tester.pumpAndSettle();

        expect(await result, 160);
      });
    });
  }
}
