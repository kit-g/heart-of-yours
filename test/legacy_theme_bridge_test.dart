import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/prose.dart';
import 'package:material_ui/material_ui.dart';

/// A dependency still on flutter/material.dart looks up that library's Theme,
/// which a material_ui app never provides, and quietly gets the framework's
/// default light one instead. markdown_widget's list bullet is the visible
/// case: near-black dots on the dark theme. HeartApp wraps every route in the
/// compatibility bridge (app_smoke_test.dart checks it is there); this is what
/// the bridge buys.
void main() {
  Future<Color?> bulletColor(WidgetTester tester, {required bool bridged}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: .dark),
        builder: (context, child) => switch (bridged) {
          // ignore: deprecated_member_use
          true => MaterialUiCompatibilityBridge(child: child!),
          false => child!,
        },
        home: const Scaffold(body: Prose('- one')),
      ),
    );
    return tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .whereType<Color>()
        .single;
  }

  testWidgets('without the bridge, a list bullet takes the default light theme', (tester) async {
    final color = await bulletColor(tester, bridged: false);
    expect(color!.computeLuminance(), lessThan(.1));
  });

  testWidgets('with it, the bullet is the app theme\'s own title colour', (tester) async {
    final color = await bulletColor(tester, bridged: true);
    final context = tester.element(find.byType(Prose));
    expect(color, Theme.of(context).textTheme.titleLarge!.color);
  });
}
