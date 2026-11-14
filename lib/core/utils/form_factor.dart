import 'dart:async';
import 'dart:ui' show Display, Size;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:heart_state/heart_state.dart' show FormFactor;

/// Whether this device is a phone, and what that allows: phones stay portrait,
/// since the layouts are not built for a 390pt-tall viewport, and tablets
/// follow the device, which large-screen guidance on both platforms asks for.
///
/// Kept true for the life of the process (#327), not settled once at launch: a
/// folding phone (iPhone Duo, Android foldables) is a phone closed and a
/// tablet open, and it can change in the middle of a workout. So the display
/// is read again whenever the window's metrics change, and the answer is acted
/// on only when it flips.
///
/// The lock has to be made per device rather than once for all, because the
/// two platforms disagree: iPadOS ignores the preference once an app allows
/// multitasking, but Android honours it. A blanket portrait lock reads as
/// "phones only" on iOS while quietly pinning Android tablets too.
///
/// The bottom bar or the rail, and one pane or two, need nothing from here:
/// they follow the window already (`LayoutProvider`).
class FormFactorWatch with WidgetsBindingObserver {
  final Future<void> Function(List<DeviceOrientation> orientations) setOrientations;

  /// Told each answer acted on, as analytics' form factor.
  final void Function(FormFactor factor) report;

  /// Told what failed to apply; the next change tries again.
  final void Function(Object error, {StackTrace? stacktrace})? onError;

  new({required this.setOrientations, required this.report, this.onError});

  static Display? _display() => WidgetsBinding.instance.platformDispatcher.implicitView?.display;

  /// The answer last acted on.
  bool? _applied;

  /// The display's size and density when last read: a change of the window
  /// alone, as the keyboard's, reads nothing more.
  (Size, double)? _measured;

  /// A retry waits for the next frame.
  var _deferred = false;

  var _watching = false;

  /// Settles the split now, and keeps it settled as the display changes.
  Future<void> start() {
    _watching = true;
    WidgetsBinding.instance.addObserver(this);
    return _apply();
  }

  /// Stops watching, and forgets what was acted on: a later [start] applies
  /// the split again.
  void stop() {
    _watching = false;
    _applied = null;
    _measured = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Acts on the answer when it differs from the last one acted on. A display
  /// with no size yet answers neither: asked again after the next frame, once.
  Future<void> _apply() async {
    if (!_watching) return;
    final display = _display();
    final measured = switch (display) {
      final Display display => (display.size, display.devicePixelRatio),
      null => null,
    };
    if (measured != null && measured == _measured && _applied != null) return;
    _measured = measured;
    final phone = _isPhone(display);
    if (phone == null) {
      if (_deferred) return;
      _deferred = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _deferred = false;
        unawaited(_apply());
      });
      return;
    }
    if (phone == _applied) return;
    try {
      report(phone ? .phone : .tablet);
      await setOrientations(phone ? const [.portraitUp] : const []);
      // only once it took: a failure is tried again on the next change
      _applied = phone;
    } catch (error, stacktrace) {
      _measured = null;
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  @override
  void didChangeMetrics() => unawaited(_apply());

  /// The conventional phone/tablet split: 600 logical pixels on the short
  /// edge of [display].
  ///
  /// Read off the display rather than a `MediaQuery`, because the orientation
  /// preference is set before there is a widget tree to read one from.
  /// Without a display (the browser) the device counts as not a phone, and
  /// stays free.
  ///
  /// Off the **display**, not the view's `physicalSize`, which is the window:
  /// it has the system bars taken out of it and it swaps its sides with the
  /// device. A 7" tablet measures 1200x1920 either way, but its window is
  /// 1200x1800 upright and 1920x1080 on its side, so a launch in landscape
  /// scored 540, called itself a phone, and pinned the tablet to portrait for
  /// the life of the process. The display is the device, whichever way up it
  /// is, which is also what `sw600dp` means on the Android side.
  ///
  /// Null is a display with no size yet: unproven, and the whole failure above
  /// was a number believed too early, so it defers rather than guesses. That
  /// happens before the first frame; mid-session the lock stays as it was
  /// until the display has a size again.
  static bool? _isPhone(Display? display) {
    return switch (display) {
      null => false,
      final display when display.size.isEmpty => null,
      final display => display.size.shortestSide / display.devicePixelRatio < 600,
    };
  }
}
