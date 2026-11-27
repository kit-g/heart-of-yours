import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:material_ui/material_ui.dart';

/// The house's quiet button (#736): drawn small, and answering taps over a full
/// target, but never over the page beside it.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(crossAxisAlignment: .stretch, children: [child]),
        ),
      ),
    );
  }

  testWidgets('stretched, it answers over what it draws and not beside it', (tester) async {
    var taps = 0;
    await pump(tester, QuietButton(onPressed: () => taps++, child: const Text('Block')));

    final row = tester.getRect(find.byType(QuietButton));
    await tester.tapAt(Offset(10, row.center.dy));
    expect(taps, 0);

    await tester.tap(find.text('Block'));
    expect(taps, 1);
  });

  testWidgets('it draws 32 and answers over 48', (tester) async {
    var taps = 0;
    await pump(tester, QuietButton(onPressed: () => taps++, child: const Text('Close')));

    final drawn = tester.getRect(find.byType(InkButton));
    expect(drawn.height, closeTo(primaryButtonMinHeight, 2));
    expect(drawn.width, greaterThanOrEqualTo(48));
    await tester.tapAt(Offset(drawn.center.dx, drawn.top - 6));
    expect(taps, 1);
  });

  testWidgets('disabled, the label is the disabled ink, and a plain one gets no fill', (tester) async {
    await pump(tester, const QuietButton(onPressed: null, plain: true, danger: true, child: Text('Block')));

    final context = tester.element(find.text('Block'));
    final ColorScheme(:onSurface) = Theme.of(context).colorScheme;
    expect(DefaultTextStyle.of(context).style.color, onSurface.withValues(alpha: .38));
    final fill = tester.widget<Material>(
      find.descendant(of: find.byType(InkButton), matching: find.byType(Material)),
    );
    expect(fill.color?.a, 0);
  });

  testWidgets('a plain one ripples in its own colour, not in black', (tester) async {
    await pump(tester, QuietButton(onPressed: () {}, plain: true, child: const Text('Skip')));

    final ColorScheme(:primary) = Theme.of(tester.element(find.text('Skip'))).colorScheme;
    expect(tester.widget<InkWell>(find.byType(InkWell)).splashColor, primary.withValues(alpha: .12));
  });
}
