import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  double progress(WidgetTester tester) {
    final builder = tester.widget<ValueListenableBuilder<double>>(find.byType(ValueListenableBuilder<double>));
    return builder.valueListenable.value;
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(.resumed);
  });

  testWidgets('a burst on screen plays at once', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: .ltr, child: Confetti()));
    await tester.pump(const Duration(seconds: 1));

    expect(progress(tester), greaterThan(0));
  });

  testWidgets('a burst built in the background waits for the app to come to the front', (tester) async {
    // a workout finished on the watch, landing while the phone app is up but
    // not in front (#206) — inactive, where frames still run; further back,
    // nothing builds until the app is opened
    tester.binding.handleAppLifecycleStateChanged(.inactive);
    await tester.pumpWidget(const Directionality(textDirection: .ltr, child: Confetti()));
    await tester.pump(const Duration(seconds: 5));
    expect(progress(tester), 0, reason: 'nobody saw it yet');

    tester.binding.handleAppLifecycleStateChanged(.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(progress(tester), greaterThan(0));
  });
}
