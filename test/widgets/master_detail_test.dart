import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/responsive/master_detail.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const list = Key('list');
  const pane = Key('pane');

  Widget page({required bool picked}) {
    return MaterialApp(
      home: Scaffold(
        body: MasterDetail(
          masterWidth: (_) => 300,
          maxMasterWidth: 600,
          master: const SizedBox.expand(key: list),
          detail: switch (picked) {
            true => const SizedBox.expand(key: pane),
            false => null,
          },
        ),
      ),
    );
  }

  testWidgets('nothing picked, the list has the page to itself, centred and capped (#685)', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(picked: false));
    expect(find.byKey(pane), findsNothing);
    expect(tester.getRect(find.byKey(list)), const Rect.fromLTWH(200, 0, 600, 800));
  });

  testWidgets('a pick slides the pane in beside a narrowed list, and clearing it takes it away (#685)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(picked: false));
    await tester.pumpWidget(page(picked: true));
    // there from the first frame, a nested navigator's place to go
    expect(find.byKey(pane), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(list)), const Rect.fromLTWH(0, 0, 300, 800));
    expect(tester.getRect(find.byKey(pane)).left, 300);

    await tester.pumpWidget(page(picked: false));
    await tester.pumpAndSettle();
    expect(find.byKey(pane), findsNothing);
    expect(tester.getRect(find.byKey(list)), const Rect.fromLTWH(200, 0, 600, 800));
  });
}
