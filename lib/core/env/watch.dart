import 'dart:async';

import 'package:flutter/services.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Watch');

/// What the watch app shows (#182). The phone is the only writer: the watch
/// holds nothing but the last of these it was sent, so every state is complete
/// on its own — never a delta against one the watch may not have.
///
/// Every string is finished copy. The watch app has no localisations of its
/// own; whatever it says, the phone said first.
sealed class WatchState {
  const new();

  Map<String, Object?> toMap();
}

/// A workout is running: the same summary the lock screen shows.
final class WatchWorkout extends WatchState {
  final OngoingWorkout workout;

  const new(this.workout);

  @override
  Map<String, Object?> toMap() {
    final OngoingWorkout(:workoutId, :startedAt, :title, :exercise, :next, :rest, :preset) = workout;
    return {
      'state': 'workout',
      'workoutId': workoutId,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'title': title,
      'exercise': exercise,
      'next': next,
      if (rest case OngoingRest rest) ...{
        'restStart': rest.start.millisecondsSinceEpoch,
        'restEnd': rest.end.millisecondsSinceEpoch,
        'restLabel': rest.label,
        'restOver': rest.over,
      },
      // the watch is always dark: only the dark half of the preset applies
      'accent': preset.dark.accent.toARGB32(),
    };
  }

  @override
  bool operator ==(Object other) => other is WatchWorkout && other.workout == workout;

  @override
  int get hashCode => workout.hashCode;
}

/// No workout is running, or the switch is off: one line saying so.
final class WatchMessage extends WatchState {
  /// `idle` or `off` — the watch draws them differently.
  final String kind;
  final String message;

  const new idle(this.message) : kind = 'idle';

  const new off(this.message) : kind = 'off';

  @override
  Map<String, Object?> toMap() => {'state': kind, 'message': message};

  @override
  bool operator ==(Object other) => other is WatchMessage && other.kind == kind && other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);
}

/// Something the watch app did.
enum WatchEvent {
  /// The watch app was launched. The first launch ever is the user's yes
  /// (`docs/opt-in.md`); every launch is also a request for the current state,
  /// which a reinstalled watch app no longer has.
  opened,

  /// A watch was paired or unpaired, or Heart installed on or removed from it.
  changed,
}

/// The phone's end of the watch app (#175), through
/// `ios/Runner/WatchChannel.swift`.
abstract interface class WatchLink {
  /// Whether a paired watch has Heart installed — what decides if the setting
  /// is offered at all.
  Future<bool> isInstalled();

  /// Replaces what the watch shows.
  Future<void> send(WatchState state);

  /// Whether the watch app was opened while nothing here was listening — a
  /// launch that happened while the phone app was not running. Asking clears
  /// it.
  Future<bool> takeOpened();

  Stream<WatchEvent> get events;
}

/// The link for [platform], or null where there is no watch app.
WatchLink? watchLink(TargetPlatform platform) {
  return switch (platform) {
    .iOS => _WatchConnectivity.instance,
    _ => null,
  };
}

/// WatchConnectivity. Like the Live Activity, every call is fire-and-report:
/// a watch that cannot be reached is never a reason to fail a workout.
class _WatchConnectivity implements WatchLink {
  static final instance = _WatchConnectivity._();

  static const _channel = MethodChannel('heart/watch');

  final _events = StreamController<WatchEvent>.broadcast();

  new _() {
    _channel.setMethodCallHandler((call) async {
      switch (WatchEvent.values.asNameMap()[call.method]) {
        case WatchEvent event:
          _events.add(event);
        case null:
          throw MissingPluginException('heart/watch has no ${call.method}');
      }
    });
  }

  @override
  Stream<WatchEvent> get events => _events.stream;

  @override
  Future<bool> isInstalled() => _ask('installed');

  @override
  Future<bool> takeOpened() => _ask('takeOpened');

  @override
  Future<void> send(WatchState state) async {
    try {
      await _channel.invokeMethod<void>('send', state.toMap());
    } on MissingPluginException {
      // a host without the channel — a widget test, an older build
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Watch send failed', e, stacktrace);
    }
  }

  Future<bool> _ask(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Watch $method failed', e, stacktrace);
      return false;
    }
  }
}
