import 'dart:async';

import 'package:flutter/widgets.dart';

/// The platform's launch screen, held over the app until there is something
/// worth showing.
///
/// Flutter takes the launch screen down on its first frame, and that frame came
/// too early: before the stored theme was applied, so the app drew in the
/// default one and repainted; before the router had read the preferences its
/// first decision waits on, so there was no page at all (a grey screen); and
/// before the profile had read anything, so its charts filled in under the
/// user's eyes. The splash itself was on screen for a blink.
///
/// [hold] defers the first frame; [release] lets it through once the app has
/// applied its theme and read what the opening page shows, but no sooner than
/// [minimum] after launch — long enough to read as a splash rather than a
/// flicker — and never later than [maximum], so a launch that cannot get ready
/// (no session offline, a slow disk) still opens.
abstract final class LaunchScreen {
  static const minimum = Duration(milliseconds: 500);
  static const maximum = Duration(milliseconds: 1500);

  /// Started by [startClock] as early as the process can: [minimum] is counted
  /// from launch, not from when the app asked to be held.
  static final _clock = Stopwatch();

  static bool _held = false;
  static bool _released = false;

  static void startClock() => _clock.start();

  /// Keeps the launch screen up. Before `runApp`: nothing is drawn until
  /// [release].
  static void hold() {
    if (_held) return;
    _held = true;
    _clock.start();
    WidgetsBinding.instance.deferFirstFrame();
    Timer(maximum - _clock.elapsed, release);
  }

  /// Lets the first frame through, once [minimum] has passed. Only the first
  /// call counts: a later session's start-up finds the app already showing.
  static Future<void> release() async {
    if (!_held || _released) return;
    _released = true;
    final remaining = minimum - _clock.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    WidgetsBinding.instance.allowFirstFrame();
  }
}
