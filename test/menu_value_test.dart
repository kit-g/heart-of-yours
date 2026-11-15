// A value-and-menu row's value (MenuValue): at the largest text on a narrow
// phone it gives way to the row's title, in a list and inside a dialog, which
// measures its content's intrinsic width.
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/menu.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const title = 'Group exercises';
  const value = 'Je préfère ne pas préciser';

  Widget row() => const ListTile(title: Text(title), trailing: MenuValue(value));

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(home: home));
  }

  void expectTitleKeepsTheRow(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    final tile = tester.getSize(find.byType(ListTile));
    expect(tester.getSize(find.byType(MenuValue)).width, lessThanOrEqualTo(tile.width * 0.4 + 0.5));
    final text = tester.widget<Text>(find.descendant(of: find.byType(MenuValue), matching: find.byType(Text)));
    expect(text.overflow, TextOverflow.ellipsis);
  }

  testWidgets('in a list, the value takes at most its share and ellipsizes', (tester) async {
    await pump(tester, Scaffold(body: ListView(children: [row()])));
    expectTitleKeepsTheRow(tester);
  });

  testWidgets('in a dialog, which asks for intrinsic widths, it lays out the same', (tester) async {
    await pump(
      tester,
      Scaffold(
        body: AlertDialog(content: SizedBox(width: 300, child: row())),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(value), findsOneWidget);
  });
}
