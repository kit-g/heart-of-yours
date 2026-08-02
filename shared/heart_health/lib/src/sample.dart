part of '../models.dart';

/// One reading from the device's health store.
///
/// Deliberately faithful to what the platform reported, including its origin.
/// Nothing is merged, averaged or reconciled on the way in — see [source] for
/// why that matters more here than it looks.
class HealthSample {
  /// The platform's own UUID for this sample.
  ///
  /// Stable across re-reads, which makes an import idempotent: the same window
  /// can be re-scanned as often as we like and rows collide on the primary key
  /// instead of accumulating. This is the whole reason a re-sync is cheap.
  final String id;

  final HealthMetric metric;

  /// Always in [HealthMetric.unit] — normalized on ingest, never mixed.
  final double value;

  final DateTime start;
  final DateTime end;

  /// Which app or device wrote the sample: `com.apple.health`, a watch, a
  /// third-party app that syncs a Garmin, and so on.
  ///
  /// Kept for two reasons. It lets us attribute honestly in the UI ("resting
  /// HR, from your Garmin"), and — the urgent one — it is the only thing that
  /// makes [HealthMetric.isCumulative] metrics safe. HealthKit will hold steps
  /// from the phone *and* the watch *and* a third app covering the same hour;
  /// they are distinct samples, not duplicates, so naive summation silently
  /// multiplies the user's step count. Any aggregate over a cumulative metric
  /// must pick one source per window rather than add them up.
  final HealthSource source;

  /// True when the user typed this in rather than a sensor recording it.
  ///
  /// Not filtered out — a hand-entered bodyweight is the most accurate number
  /// in the store — but a narrative should know the difference before drawing
  /// a conclusion from it.
  final bool isManual;

  const HealthSample({
    required this.id,
    required this.metric,
    required this.value,
    required this.start,
    required this.end,
    required this.source,
    this.isManual = false,
  });

  /// The columns of the local `health_samples` table, exactly.
  ///
  /// heart_db spreads this straight into an insert, so every key here must be a
  /// column and every column not defaulted must be a key. `user_id` is
  /// deliberately absent: it is context the caller holds, not a property of the
  /// reading, and heart_db injects it — the same split `Template.toRow()` makes.
  Map<String, Object?> toRow() {
    return {
      'id': id,
      'metric': metric.value,
      'value': value,
      'unit': metric.unit.value,
      // Normalized to UTC so the stored string always carries a `Z`. Without
      // it, a local-time reading is indistinguishable from a UTC one, and
      // SQLite's `date(start, 'localtime')` — how a day is bucketed for charts
      // — would shift it a second time.
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'source_id': source.id,
      'source_name': source.name,
      'device_model': source.deviceModel,
      'is_manual': isManual ? 1 : 0,
    };
  }

  factory HealthSample.fromRow(Map<String, Object?> row) {
    return HealthSample(
      id: row['id']! as String,
      metric: HealthMetric.fromString(row['metric']! as String),
      value: (row['value']! as num).toDouble(),
      start: DateTime.parse(row['start']! as String),
      end: DateTime.parse(row['end']! as String),
      source: HealthSource(
        id: row['source_id'] as String? ?? '',
        name: row['source_name'] as String? ?? '',
        deviceModel: row['device_model'] as String?,
      ),
      isManual: row['is_manual'] == 1,
    );
  }

  @override
  String toString() => '${metric.value} $value${metric.unit.value} @ $start from ${source.name}';
}

/// Where a [HealthSample] came from.
class HealthSource {
  /// Bundle id of the writing app, e.g. `com.apple.health` for the phone
  /// itself or `com.garmin.connect.mobile` for a synced Garmin.
  final String id;

  /// Display name of the writing app, as the platform reports it.
  final String name;

  /// The recording hardware — "Apple Watch", "iPhone". **iOS only**; Health
  /// Connect does not expose an equivalent and this is always null there.
  final String? deviceModel;

  const HealthSource({
    required this.id,
    required this.name,
    this.deviceModel,
  });

  @override
  String toString() => deviceModel == null ? name : '$name ($deviceModel)';
}
