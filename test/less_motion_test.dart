import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<bool> asked(WidgetTester tester, FakeAccessibilityFeatures features) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = features;
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    late bool less;
    await tester.pumpWidget(
      MediaQuery.fromView(
        view: tester.view,
        child: Builder(
          builder: (context) {
            less = lessMotion(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return less;
  }

  testWidgets("iOS's Reduce Motion asks for less motion (#595)", (tester) async {
    expect(await asked(tester, const FakeAccessibilityFeatures(reduceMotion: true)), isTrue);
  });

  testWidgets("Android's Remove animations asks for less motion", (tester) async {
    expect(await asked(tester, const FakeAccessibilityFeatures(disableAnimations: true)), isTrue);
  });

  testWidgets('neither flag is no preference', (tester) async {
    expect(await asked(tester, const FakeAccessibilityFeatures()), isFalse);
  });

  testWidgets('no MediaQuery above is no preference', (tester) async {
    late bool less;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          less = lessMotion(context);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(less, isFalse);
  });
}
