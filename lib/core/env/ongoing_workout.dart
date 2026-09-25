import 'package:flutter/services.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:logging/logging.dart';

final _logger = Logger('OngoingWorkout');

/// A rest countdown as the lock screen draws it: the window it spans, and the
/// copy for while it runs and once it has run out.
typedef OngoingRest = ({DateTime start, DateTime end, String label, String over});

/// The active workout, summarised for surfaces outside the app (#133): the
/// iOS Live Activity (lock screen, Dynamic Island) and Android's ongoing
/// notification.
///
/// Every string is finished copy — presentation localises and formats it,
/// the native side only lays it out. The times are instants, never counts:
/// both platforms tick a clock natively between updates, so the app speaks
/// only when something *changes*, never once a second.
///
/// A record so that two snapshots of the same state compare equal, which is
/// what lets the caller skip redundant platform calls.
typedef OngoingWorkout = ({
  String workoutId,
  DateTime startedAt,
  String title,
  String exercise,
  String next,
  OngoingRest? rest,

  /// The theme the user picked. The lock screen follows the *system*
  /// brightness, not the app's, so the surfaces take both halves of the
  /// preset and choose per appearance.
  Preset preset,

  /// Android's notification channel name, shown in the system settings.
  String channel,
});

/// Where [OngoingWorkout] is shown. [show] starts or updates it, [end]
/// withdraws it; both are safe to repeat.
abstract interface class OngoingWorkoutSurface {
  /// Whether this device can show it at all — what decides if the setting is
  /// offered. False on an iPad or below iOS 16.2, which have no Live
  /// Activities.
  Future<bool> isSupported();

  Future<void> show(OngoingWorkout workout);

  Future<void> end();
}

/// The surface for [platform], or null where there is none.
OngoingWorkoutSurface? ongoingWorkoutSurface(TargetPlatform platform) {
  return switch (platform) {
    .iOS => const _LiveActivity(),
    .android => const _OngoingNotification(),
    _ => null,
  };
}

/// ActivityKit, through `ios/Runner/OngoingWorkoutChannel.swift`.
///
/// The native side owns everything ActivityKit is picky about — availability
/// (iOS 16.2+, iPhone only, the user's per-app switch), re-attaching to an
/// activity that outlived the process, and ending strays — so every call here
/// is fire-and-report: a lock screen that cannot be drawn is never a reason to
/// fail a workout.
class _LiveActivity implements OngoingWorkoutSurface {
  static const _channel = MethodChannel('heart/ongoing_workout');

  const new();

  @override
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Live Activity support check failed', e, stacktrace);
      return false;
    }
  }

  @override
  Future<void> show(OngoingWorkout workout) {
    return _guarded(
      'show',
      {
        'workoutId': workout.workoutId,
        'startedAt': workout.startedAt.millisecondsSinceEpoch,
        'title': workout.title,
        'exercise': workout.exercise,
        'next': workout.next,
        if (workout.rest case OngoingRest rest) ...{
          'restStart': rest.start.millisecondsSinceEpoch,
          'restEnd': rest.end.millisecondsSinceEpoch,
          'restLabel': rest.label,
          'restOver': rest.over,
        },
        // ARGB ints; the native side picks per appearance
        'accent': workout.preset.light.accent.toARGB32(),
        'accentDark': workout.preset.dark.accent.toARGB32(),
        'accentInk': workout.preset.light.accentInk.toARGB32(),
        'accentInkDark': workout.preset.dark.accentInk.toARGB32(),
      },
    );
  }

  @override
  Future<void> end() => _guarded('end');

  Future<void> _guarded(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // a host without the channel — a widget test, an older build
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Live Activity $method failed', e, stacktrace);
    }
  }
}

class _OngoingNotification implements OngoingWorkoutSurface {
  const new();

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> show(OngoingWorkout workout) => showOngoingWorkoutNotification(workout);

  @override
  Future<void> end() => cancelOngoingWorkoutNotification();
}
