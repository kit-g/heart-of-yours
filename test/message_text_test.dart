import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/message_runs.dart';
import 'package:heart/presentation/widgets/message_text.dart';

/// The words and their time, laid out as one (#556), and how a conversation
/// groups its messages.
void main() {
  // the test font: every glyph is a square as wide as the size
  const style = TextStyle(fontSize: 10, height: 1);
  const timeStyle = TextStyle(fontSize: 6, height: 1);

  Widget host(
    String text, {
    double width = 200,
    TextDirection direction = .ltr,
    TextScaler scaler = TextScaler.noScaling,
    ValueChanged<Uri>? onLink,
    String time = '9:41',
  }) {
    return MediaQuery(
      data: MediaQueryData(textScaler: scaler),
      child: Directionality(
        textDirection: direction,
        child: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: width,
            child: Align(
              alignment: .topLeft,
              child: MessageText(
                text: text,
                style: style,
                linkStyle: style,
                time: time,
                timeStyle: timeStyle,
                semanticsLabel: '$text, $time',
                onLink: onLink,
                linkAction: (link) => 'Open $link',
              ),
            ),
          ),
        ),
      ),
    );
  }

  RenderMessageText render(WidgetTester tester) => tester.renderObject(find.byType(MessageText));

  group('the time', () {
    testWidgets('sits beside a short message, on its line', (tester) async {
      await tester.pumpWidget(host('Hi'));

      // two glyphs, the gap, four of the time's
      expect(render(tester).size, const Size(20 + 8 + 24, 10));
    });

    testWidgets('goes under a last line that leaves no room', (tester) async {
      await tester.pumpWidget(host('x' * 19));

      expect(render(tester).size, const Size(190, 16));
    });

    testWidgets('beside the last of several lines, however short the longest', (tester) async {
      // the widget this came from put the time under "2" here
      await tester.pumpWidget(host('1\n2'));

      expect(render(tester).size, const Size(10 + 8 + 24, 20));
    });

    testWidgets('a wrapped message is as wide as its longest line, not the width given', (tester) async {
      await tester.pumpWidget(host('aaaa bbbbbbbbbbbbbbbb cc', width: 180));

      // "aaaa" / "bbbbbbbbbbbbbbbb" (160) / "cc" with the time beside it
      expect(render(tester).size.width, 160);
      expect(render(tester).size.height, 30);
    });

    testWidgets('grows with the reader\'s text size', (tester) async {
      await tester.pumpWidget(host('Hi', scaler: const TextScaler.linear(2)));

      expect(render(tester).size, const Size(40 + 8 + 48, 20));
    });
  });

  testWidgets('right to left, the time takes the left end', (tester) async {
    await tester.pumpWidget(host('x' * 19, direction: .rtl));
    final box = render(tester);

    // the words' painter is right-aligned within the box; the time starts at 0
    expect(box.size, const Size(190, 16));
    expect(tester.getSemantics(find.byType(MessageText)).textDirection, TextDirection.rtl);
  });

  group('links', () {
    testWidgets('a tap on one opens it', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(host('see https://heart-of.me now', width: 400, onLink: opened.add));

      // "see " is 40 wide: the link starts after it
      await tester.tapAt(tester.getTopLeft(find.byType(MessageText)) + const Offset(60, 5));
      expect(opened, [Uri.parse('https://heart-of.me')]);
    });

    testWidgets('a tap beside one opens nothing', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(host('see https://heart-of.me now', width: 400, onLink: opened.add));

      await tester.tapAt(tester.getTopLeft(find.byType(MessageText)) + const Offset(10, 5));
      expect(opened, isEmpty);
    });

    testWidgets('www. and email addresses are links too, and numbers with dots are not', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(host('www.heart-of.me', onLink: opened.add));
      await tester.tapAt(tester.getTopLeft(find.byType(MessageText)) + const Offset(5, 5));
      await tester.pumpWidget(host('muffin@heart-of.me', onLink: opened.add));
      await tester.tapAt(tester.getTopLeft(find.byType(MessageText)) + const Offset(5, 5));
      await tester.pumpWidget(host('2.5 kg e.g. this', onLink: opened.add));
      await tester.tapAt(tester.getTopLeft(find.byType(MessageText)) + const Offset(5, 5));

      expect(opened, [Uri.parse('https://www.heart-of.me'), Uri.parse('mailto:muffin@heart-of.me')]);
    });

    testWidgets('without onLink, a link is words', (tester) async {
      await tester.pumpWidget(host('https://heart-of.me'));

      final node = tester.getSemantics(find.byType(MessageText));
      expect(node.getSemanticsData().customSemanticsActionIds, isEmpty);
    });

    testWidgets('a screen reader is offered each link as an action', (tester) async {
      final handle = tester.ensureSemantics();
      final opened = <Uri>[];
      await tester.pumpWidget(host('a https://heart-of.me b muffin@heart-of.me', width: 600, onLink: opened.add));

      final node = tester.getSemantics(find.byType(MessageText));
      expect(node.label, 'a https://heart-of.me b muffin@heart-of.me, 9:41');
      final actions = [
        for (final id in node.getSemanticsData().customSemanticsActionIds ?? <int>[])
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(actions, ['Open https://heart-of.me', 'Open muffin@heart-of.me']);
      handle.dispose();
    });
  });

  group('runs', () {
    final noon = DateTime(2026, 11, 12, 12);

    test('one writer within a few minutes is one run', () {
      final places = const MessageRuns().of([
        (at: noon, mine: true),
        (at: noon.add(const Duration(minutes: 1)), mine: true),
        (at: noon.add(const Duration(minutes: 2)), mine: true),
      ]);

      expect(places, [
        (newDay: true, firstOfRun: true, lastOfRun: false),
        (newDay: false, firstOfRun: false, lastOfRun: false),
        (newDay: false, firstOfRun: false, lastOfRun: true),
      ]);
    });

    test('the other person, a pause, or a new day breaks it', () {
      final places = const MessageRuns().of([
        (at: noon, mine: true),
        (at: noon.add(const Duration(minutes: 1)), mine: false),
        (at: noon.add(const Duration(minutes: 30)), mine: false),
        (at: noon.add(const Duration(hours: 13)), mine: false),
      ]);

      expect(places.map((each) => each.firstOfRun), [true, true, true, true]);
      expect(places.map((each) => each.newDay), [true, false, false, true]);
    });
  });
}
