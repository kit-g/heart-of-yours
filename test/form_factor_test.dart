import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/form_factor.dart';
import 'package:heart_state/heart_state.dart' show FormFactor;

/// The phone-or-tablet split, kept true as a folding phone opens and closes
/// (#327): acted on when it flips, and only then.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool? phone;
  late List<List<DeviceOrientation>> locks;
  late List<FormFactor> reported;
  late FormFactorWatch watch;

  setUp(() {
    phone = true;
    locks = [];
    reported = [];
    watch = FormFactorWatch(
      isPhone: () => phone,
      setOrientations: (orientations) async => locks.add(orientations),
      report: reported.add,
    );
  });

  tearDown(() => watch.stop());

  test('a phone is held portrait from the start', () async {
    await watch.start();

    expect(locks, [
      [DeviceOrientation.portraitUp],
    ]);
    expect(reported, [FormFactor.phone]);
  });

  test('opened, it follows the device; closed again, portrait again', () async {
    await watch.start();

    phone = false;
    watch.didChangeMetrics();
    await pumpEventQueue();
    phone = true;
    watch.didChangeMetrics();
    await pumpEventQueue();

    expect(locks, [
      [DeviceOrientation.portraitUp],
      <DeviceOrientation>[],
      [DeviceOrientation.portraitUp],
    ]);
    expect(reported, [FormFactor.phone, FormFactor.tablet, FormFactor.phone]);
  });

  test("a change that doesn't flip it, as a rotation or a keyboard, does nothing", () async {
    await watch.start();

    watch.didChangeMetrics();
    watch.didChangeMetrics();
    await pumpEventQueue();

    expect(locks, hasLength(1));
    expect(reported, [FormFactor.phone]);
  });

  testWidgets('a display with no size yet is asked again after a frame', (tester) async {
    phone = null;
    await watch.start();
    expect(locks, isEmpty);

    phone = false;
    tester.binding.scheduleFrame();
    await tester.pump();

    expect(locks, [<DeviceOrientation>[]]);
    expect(reported, [FormFactor.tablet]);
  });
}
