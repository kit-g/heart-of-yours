import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/heading_row.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const heading = SizedBox(width: 100, height: 20);
  const action = SizedBox(width: 80, height: 30);

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Align(alignment: .topLeft, child: child),
      ),
    );
  }

  testWidgets('fills a loose width and puts the actions at its end', (tester) async {
    // Align hands down a loose width: a Wrap with spaceBetween would come out
    // as wide as its line, the action right after the heading
    await pump(
      tester,
      const SizedBox(
        width: 300,
        child: Align(
          alignment: .topLeft,
          child: HeadingRow(heading: heading, actions: [action]),
        ),
      ),
    );

    expect(tester.getSize(find.byType(HeadingRow)), const Size(300, 30));
    expect(tester.getRect(find.byWidget(heading)), const Rect.fromLTWH(0, 5, 100, 20));
    expect(tester.getRect(find.byWidget(action)), const Rect.fromLTWH(220, 0, 80, 30));
  });

  testWidgets('puts the actions under the heading when they do not fit beside it', (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 150,
        child: HeadingRow(heading: heading, actions: [action], runSpacing: 6),
      ),
    );

    expect(tester.getSize(find.byType(HeadingRow)), const Size(150, 56));
    expect(tester.getRect(find.byWidget(heading)), const Rect.fromLTWH(0, 0, 100, 20));
    expect(tester.getRect(find.byWidget(action)), const Rect.fromLTWH(0, 26, 80, 30));
  });

  testWidgets('is its content under an unbounded width', (tester) async {
    await pump(
      tester,
      const SingleChildScrollView(
        scrollDirection: .horizontal,
        child: HeadingRow(heading: heading, actions: [action], spacing: 12),
      ),
    );

    expect(tester.getSize(find.byType(HeadingRow)), const Size(192, 30));
    expect(tester.getRect(find.byWidget(action)), const Rect.fromLTWH(112, 0, 80, 30));
  });

  testWidgets('mirrors right to left', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: .rtl,
        child: Center(
          child: SizedBox(
            width: 300,
            child: HeadingRow(heading: heading, actions: [action]),
          ),
        ),
      ),
    );

    final row = tester.getTopLeft(find.byType(HeadingRow));
    expect(tester.getTopLeft(find.byWidget(heading)) - row, const Offset(200, 5));
    expect(tester.getTopLeft(find.byWidget(action)) - row, Offset.zero);
  });

  testWidgets('answers an intrinsic width, which a layout builder cannot', (tester) async {
    await pump(
      tester,
      const IntrinsicWidth(
        child: HeadingRow(heading: heading, actions: [action], spacing: 12),
      ),
    );

    expect(tester.getSize(find.byType(HeadingRow)).width, 192);
  });
}
