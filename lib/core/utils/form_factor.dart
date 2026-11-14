import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:heart_state/heart_state.dart' show FormFactor;

/// Whether this device is a phone, and what that allows: phones stay portrait,
/// since the layouts are not built for a 390pt-tall viewport, and tablets
/// follow the device, which large-screen guidance on both platforms asks for.
///
/// Kept true for the life of the process (#327), not settled once at launch: a
/// folding phone (iPhone Duo, Android foldables) is a phone closed and a
/// tablet open, and it can change in the middle of a workout. So the answer is
/// asked again whenever the display's metrics change, and acted on only when
/// it flips.
///
/// The lock has to be made per device rather than once for all, because the
/// two platforms disagree: iPadOS ignores the preference once an app allows
/// multitasking, but Android honours it. A blanket portrait lock reads as
/// "phones only" on iOS while quietly pinning Android tablets too.
///
/// The bottom bar or the rail, and one pane or two, need nothing from here:
/// they follow the window already (`LayoutProvider`).
class FormFactorWatch with WidgetsBindingObserver {
  /// Whether the display is a phone's; null while it has no size yet.
  final bool? Function() isPhone;

  final Future<void> Function(List<DeviceOrientation> orientations) setOrientations;

  /// Told each answer acted on, as analytics' form factor.
  final void Function(FormFactor factor) report;

  new({required this.isPhone, required this.setOrientations, required this.report});

  /// The answer last acted on.
  bool? _applied;

  /// Settles the split now, and keeps it settled as the display changes.
  Future<void> start() {
    WidgetsBinding.instance.addObserver(this);
    return apply();
  }

  void stop() => WidgetsBinding.instance.removeObserver(this);

  /// Acts on the answer when it differs from the last one. An unmeasured
  /// display answers neither: asked again after the next frame, the first
  /// moment its size is certainly real. Nothing is on screen until then, so
  /// the wait costs nothing.
  Future<void> apply() {
    final phone = isPhone();
    if (phone == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      return Future.value();
    }
    if (phone == _applied) return Future.value();
    _applied = phone;
    report(phone ? .phone : .tablet);
    return setOrientations(switch (phone) {
      true => const [DeviceOrientation.portraitUp],
      false => const <DeviceOrientation>[],
    });
  }

  @override
  void didChangeMetrics() => unawaited(apply());
}
