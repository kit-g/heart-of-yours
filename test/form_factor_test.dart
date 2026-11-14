import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/form_factor.dart';
import 'package:heart_state/heart_state.dart' show FormFactor;

/// The phone-or-tablet split, read off the display and kept true as a folding
/// phone opens and closes (#327): acted on when it flips, and only then.
/// Sizes are iPhone Duo's displays at 3x: closed and open.
void main() {
  const closed = Size(1398, 2034);
  const open = Size(2007, 2853);

  late List<List<DeviceOrientation>> locks;
  late List<FormFactor> reported;
  late List<Object> errors;
  late FormFactorWatch watch;
  var failNext = false;

  Future<void> start(WidgetTester tester, Size display) async {
    tester.view.display.size = display;
    tester.view.display.devicePixelRatio = 3;
    addTearDown(tester.view.display.reset);
    locks = [];
    reported = [];
    errors = [];
    failNext = false;
    watch = FormFactorWatch(
      setOrientations: (orientations) async {
        if (failNext) {
          failNext = false;
          throw PlatformException(code: 'busy');
        }
        locks.add(orientations);
      },
      report: reported.add,
      onError: (error, {stacktrace}) => errors.add(error),
    );
    addTearDown(watch.stop);
    await watch.start();
  }

  Future<void> fold(WidgetTester tester, Size display) async {
    tester.view.display.size = display;
    watch.didChangeMetrics();
    await tester.pump();
  }

  testWidgets('a phone is held portrait from the start', (tester) async {
    await start(tester, closed);

    expect(locks, [
      [DeviceOrientation.portraitUp],
    ]);
    expect(reported, [FormFactor.phone]);
  });

  testWidgets('opened, it follows the device; closed again, portrait again', (tester) async {
    await start(tester, closed);

    await fold(tester, open);
    await fold(tester, closed);

    expect(locks, [
      [DeviceOrientation.portraitUp],
      <DeviceOrientation>[],
      [DeviceOrientation.portraitUp],
    ]);
    expect(reported, [FormFactor.phone, FormFactor.tablet, FormFactor.phone]);
  });

  testWidgets('the window changing alone, as the keyboard does, does nothing', (tester) async {
    await start(tester, closed);

    watch.didChangeMetrics();
    watch.didChangeMetrics();
    await tester.pump();

    expect(locks, hasLength(1));
  });

  testWidgets('a display with no size yet is asked again after a frame, once', (tester) async {
    await start(tester, Size.zero);
    watch.didChangeMetrics();
    watch.didChangeMetrics();
    expect(locks, isEmpty);

    tester.view.display.size = open;
    tester.binding.scheduleFrame();
    await tester.pump();

    expect(locks, [<DeviceOrientation>[]]);
    expect(reported, [FormFactor.tablet]);
  });

  testWidgets('a lock that fails is reported, and tried again on the next change', (tester) async {
    await start(tester, closed);
    failNext = true;

    await fold(tester, open);
    expect(errors, hasLength(1));
    expect(locks, hasLength(1));

    watch.didChangeMetrics();
    await tester.pump();
    expect(locks.last, <DeviceOrientation>[]);
  });

  testWidgets('a start after a stop applies the split again', (tester) async {
    await start(tester, closed);

    watch.stop();
    await watch.start();

    expect(locks, hasLength(2));
  });
}
