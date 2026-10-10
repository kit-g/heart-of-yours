import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/launch_screen.dart';

/// The launch screen stays up until the app is ready, for at least the
/// minimum from launch, and the first frame is let through exactly once.
/// Static state: one process, one launch — so one test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('holds the first frame, releases it no sooner than the minimum, and only once', () async {
    LaunchScreen.startClock();
    LaunchScreen.hold();
    expect(WidgetsBinding.instance.sendFramesToEngine, isFalse);

    // ready at once: still held until the minimum has passed since launch
    final released = LaunchScreen.release();
    await Future<void>.delayed(LaunchScreen.minimum ~/ 2);
    expect(WidgetsBinding.instance.sendFramesToEngine, isFalse);

    await released;
    expect(WidgetsBinding.instance.sendFramesToEngine, isTrue);

    // a later session's start-up, and the maximum's timer, change nothing —
    // a second allowFirstFrame would trip the binding's own assertion
    await LaunchScreen.release();
    await Future<void>.delayed(LaunchScreen.maximum);
    expect(WidgetsBinding.instance.sendFramesToEngine, isTrue);
  });
}
