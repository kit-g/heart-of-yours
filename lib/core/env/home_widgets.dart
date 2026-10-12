import 'package:flutter/services.dart';
import 'package:heart/core/utils/training_days.dart';
import 'package:heart_models/heart_models.dart';
import 'package:logging/logging.dart';

final _logger = Logger('HomeWidgets');

/// What the training widget (#161) draws from, handed to the platform's
/// widget layer: per-day totals, the unit a volume is shown in, and the
/// theme's accent for the bars. No words: the widget's copy is native, in the
/// device's language, since it shows in the widget gallery with the app not
/// running. No health data either, though the contract would allow it (see
/// `docs/2026-09-05.health-data.md`).
///
/// The widget picks its own window — the last 7 days, the last 3 months —
/// from these days and today's date, so it rolls over at midnight with the
/// app closed.
final class TrainingSnapshot {
  final Map<DateTime, TrainingDay> days;
  final MeasurementUnit unit;

  /// `Color.toARGB32()` of the theme's accent, light and dark.
  final int accent;
  final int accentDark;

  const new({required this.days, required this.unit, required this.accent, required this.accentDark});

  /// Days as `yyyy-MM-dd`, each `[volume kg, workouts, seconds, sets, reps]`:
  /// a few kilobytes for three months of daily training.
  Map<String, Object> toMap() {
    return {
      'version': 1,
      'unit': unit.name,
      'accent': accent,
      'accentDark': accentDark,
      'days': {
        for (final MapEntry(key: day, value: total) in days.entries)
          _date(day): [
            (total.volume * 10).round() / 10,
            total.workouts,
            total.seconds,
            total.sets,
            total.reps,
          ],
      },
    };
  }

  static String _date(DateTime day) {
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }
}

/// The Home Screen's widgets: WidgetKit on iOS, App Widgets on Android.
abstract interface class HomeWidgets {
  /// Replaces what the training widget draws from and redraws it; null when
  /// there is nobody's training to show, which draws it empty.
  Future<void> setTraining(TrainingSnapshot? snapshot);
}

/// Null where there are no Home Screen widgets.
HomeWidgets? homeWidgets(TargetPlatform platform) {
  return switch (platform) {
    .iOS || .android => _MethodChannelHomeWidgets.instance,
    .fuchsia || .linux || .macOS || .windows => null,
  };
}

/// Fire-and-report, like the shortcuts: a widget that cannot be told is never
/// a reason to fail anything in the app.
class _MethodChannelHomeWidgets implements HomeWidgets {
  static final instance = _MethodChannelHomeWidgets._();

  static const _channel = MethodChannel('heart/widgets');

  new _();

  @override
  Future<void> setTraining(TrainingSnapshot? snapshot) async {
    try {
      await _channel.invokeMethod<void>('setTraining', snapshot?.toMap());
    } on MissingPluginException {
      // a build without the native side: nothing to tell
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Training widget update failed', e, stacktrace);
    }
  }
}
