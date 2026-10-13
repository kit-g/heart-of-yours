import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _logger = Logger('GoalsWidget');

/// One goal as the Goals widget (#368) draws it: the words the profile's goal
/// row shows, in the app's language at the time it was published, and how far
/// along the current rung the user is.
final class WidgetGoal {
  final String id;

  /// "Workouts", or "Bench Press (Barbell) — Estimated 1RM".
  final String title;

  /// "2 / 4 · per week", in the user's units.
  final String status;

  /// 0 to 1 toward the current rung; 1 once the ladder is done.
  final double progress;

  const new({required this.id, required this.title, required this.status, required this.progress});

  Map<String, Object> toMap() => {'id': id, 'title': title, 'status': status, 'progress': progress};
}

/// What the Goals widget draws from: the user's active goals, closest to done
/// first. Training goals only for now; a goal over a health metric would be
/// redacted on the lock screen (`docs/2026-09-05.health-data.md`).
final class GoalsSnapshot {
  final List<WidgetGoal> goals;

  const new(this.goals);

  Map<String, Object> toMap() => {
    'version': 1,
    'goals': [for (final goal in goals) goal.toMap()],
  };
}

/// The Home Screen's Goals widget: WidgetKit on iOS, an App Widget on Android.
abstract interface class GoalsWidget {
  /// Replaces what the widget draws from and redraws it; null when there is
  /// nobody's goals to show, which draws it as if there were none.
  Future<void> setGoals(GoalsSnapshot? snapshot);
}

/// Null where there are no Home Screen widgets.
GoalsWidget? goalsWidget(TargetPlatform platform) {
  return switch (platform) {
    .iOS || .android => _MethodChannelGoalsWidget.instance,
    .fuchsia || .linux || .macOS || .windows => null,
  };
}

/// Fire-and-report, like the training widget: a widget that cannot be told is
/// never a reason to fail anything in the app.
class _MethodChannelGoalsWidget implements GoalsWidget {
  static final instance = _MethodChannelGoalsWidget._();

  static const _channel = MethodChannel('heart/widgets');

  new _();

  @override
  Future<void> setGoals(GoalsSnapshot? snapshot) async {
    try {
      await _channel.invokeMethod<void>('setGoals', snapshot?.toMap());
    } on MissingPluginException {
      // a build without the native side: nothing to tell
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Goals widget update failed', e, stacktrace);
    }
  }
}
