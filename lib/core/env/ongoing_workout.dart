import 'dart:async';

import 'package:flutter/services.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:logging/logging.dart';

final _logger = Logger('OngoingWorkout');

/// A rest countdown as the lock screen draws it: the window it spans, the
/// copy for while it runs and once it has run out, and the labels of its
/// buttons (#141): ten seconds off, ten on, skip.
typedef OngoingRest = ({
  DateTime start,
  DateTime end,
  String label,
  String over,
  String minus,
  String plus,
  String skip,
});

/// The Done button on the lock screen (#246): the set up next, which it ticks,
/// and what the surface shows the moment it has — before the app has heard —
/// so the button answers at once: the lines that follow, and the rest the
/// exercise's timer starts, with the copy of its notification and its own
/// buttons. Null when there is no set to tick, or it cannot be ticked as it
/// stands.
typedef OngoingDone = ({
  String setId,
  String exerciseId,
  String label,
  String afterExercise,
  String afterNext,

  /// The rest that starts on the tick, in seconds; null for an exercise with
  /// no rest timer.
  int? restSeconds,
  String restLabel,
  String restOver,
  String restMinus,
  String restPlus,
  String restSkip,

  /// The "rest complete" notification's copy, for the surface to schedule
  /// as the app would: title, body (the set that follows, if any) and
  /// subtitle naming the exercise.
  String restTitle,
  String? restBody,
  String restSubtitle,
});

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

  /// When the workout began, as a wall-clock time. Not where its clock counts
  /// from once it has been paused: that is [clockStart].
  DateTime startedAt,

  /// Where the elapsed clock counts from: [startedAt] moved on by every pause
  /// the workout has closed (#134).
  DateTime clockStart,

  /// While the workout is paused, when it was: the clock stands at
  /// `pausedAt − clockStart` until it runs again.
  DateTime? pausedAt,

  /// "Paused", for a stopped clock.
  String pausedLabel,
  String title,
  String exercise,
  String next,
  OngoingRest? rest,

  /// The set up next and what ticking it shows (#246).
  OngoingDone? done,

  /// A timed set's stopwatch (#171): its effective start, and when it
  /// paused while it is paused.
  ({DateTime start, DateTime? pausedAt, String label})? stopwatch,

  /// The theme the user picked. The lock screen follows the *system*
  /// brightness, not the app's, so the surfaces take both halves of the
  /// preset and choose per appearance.
  Preset preset,

  /// Android's notification channel name, shown in the system settings.
  String channel,
});

/// Where [OngoingWorkout] is shown. [show] starts or updates it, [end]
/// withdraws it; both are safe to repeat.
///
/// It also speaks back (#141): the rest buttons on it send the same commands
/// the watch does, as requests the app applies — the surface has shown the
/// result already, and the next [show] confirms or corrects it.
abstract interface class OngoingWorkoutSurface {
  /// Whether this device can show it at all — what decides if the setting is
  /// offered. False on an iPad or below iOS 16.2, which have no Live
  /// Activities.
  Future<bool> isSupported();

  Future<void> show(OngoingWorkout workout);

  Future<void> end();

  /// Commands from the surface's buttons, as they arrive.
  Stream<WatchCommand> get commands;

  /// Commands pressed while nothing here was listening — the app was not
  /// running, or not yet — oldest first. Asking clears them.
  Future<List<WatchCommand>> takeCommands();
}

/// The surface for [platform], or null where there is none.
OngoingWorkoutSurface? ongoingWorkoutSurface(TargetPlatform platform) {
  return switch (platform) {
    .iOS => _LiveActivity.instance,
    .android => _OngoingNotification.instance,
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
  static final instance = _LiveActivity._();

  static const _channel = MethodChannel('heart/ongoing_workout');

  final _commands = StreamController<WatchCommand>.broadcast();

  new _() {
    _channel.setMethodCallHandler((call) async {
      switch ((call.method, call.arguments)) {
        // the answer tells the native side whether anyone was listening; if
        // not, it keeps the command for [takeCommands]
        case ('command', Map arguments):
          if (!_commands.hasListener) return false;
          if (WatchCommand.fromMap(arguments) case WatchCommand command) _commands.add(command);
          return true;
        default:
          throw MissingPluginException('heart/ongoing_workout has no ${call.method}');
      }
    });
  }

  @override
  Stream<WatchCommand> get commands => _commands.stream;

  @override
  Future<List<WatchCommand>> takeCommands() async {
    try {
      final queued = await _channel.invokeListMethod<Map<Object?, Object?>>('takeCommands') ?? const [];
      return queued.map(WatchCommand.fromMap).nonNulls.toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Live Activity takeCommands failed', e, stacktrace);
      return const [];
    }
  }

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
        'clockStart': workout.clockStart.millisecondsSinceEpoch,
        'pausedAt': ?workout.pausedAt?.millisecondsSinceEpoch,
        'pausedLabel': workout.pausedLabel,
        'title': workout.title,
        'exercise': workout.exercise,
        'next': workout.next,
        if (workout.rest case OngoingRest rest) ...{
          'restStart': rest.start.millisecondsSinceEpoch,
          'restEnd': rest.end.millisecondsSinceEpoch,
          'restLabel': rest.label,
          'restOver': rest.over,
          'restMinus': rest.minus,
          'restPlus': rest.plus,
          'restSkip': rest.skip,
        },
        if (workout.stopwatch case final clock?) ...{
          'stopwatchStart': clock.start.millisecondsSinceEpoch,
          'stopwatchLabel': clock.label,
          if (clock.pausedAt case final at?) 'stopwatchPausedAt': at.millisecondsSinceEpoch,
        },
        if (workout.done case OngoingDone done) ...{
          'doneSetId': done.setId,
          'doneExerciseId': done.exerciseId,
          'doneLabel': done.label,
          'afterExercise': done.afterExercise,
          'afterNext': done.afterNext,
          'afterRest': ?done.restSeconds,
          'afterRestLabel': done.restLabel,
          'afterRestOver': done.restOver,
          'afterRestMinus': done.restMinus,
          'afterRestPlus': done.restPlus,
          'afterRestSkip': done.restSkip,
          'afterRestTitle': done.restTitle,
          'afterRestBody': ?done.restBody,
          'afterRestSubtitle': done.restSubtitle,
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
  static final instance = _OngoingNotification._();

  new _();

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<WatchCommand> get commands => ongoingNotificationCommands;

  @override
  Future<List<WatchCommand>> takeCommands() => takeOngoingNotificationCommands();

  @override
  Future<void> show(OngoingWorkout workout) => showOngoingWorkoutNotification(workout);

  @override
  Future<void> end() => cancelOngoingWorkoutNotification();
}
