part of '../models.dart';

/// One day's worth of a metric, already reconciled across sources.
typedef HealthDailyValue = ({DateTime day, double value});

/// Local persistence for health samples.
///
/// Declared here rather than in `heart_db` for the same reason `heart_models`
/// declares `WorkoutService`: the vocabulary belongs with the domain, and the
/// state layer should be able to mock storage without importing SQLite.
///
/// Implemented by `LocalDatabase`. **There is no remote counterpart, and there
/// must not be** — health data is device-only.
abstract interface class HealthSampleStore {
  /// Upserts [samples]. Rows collide on the platform's own sample UUID, so
  /// re-reading a window that was already imported is a no-op rather than a
  /// duplicate — which is what makes an overlapping re-sync safe.
  Future<void> storeHealthSamples(Iterable<HealthSample> samples, String userId);

  /// Every stored sample of [metric] in `[from, to)`, oldest first, with its
  /// source intact. Unreconciled — see [getDailyHealth] for the safe aggregate.
  Future<List<HealthSample>> getHealthSamples({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  });

  /// When [metric] was last recorded, or null if never.
  ///
  /// The watermark for an incremental sync: read from here rather than
  /// rescanning years of store on every launch.
  Future<DateTime?> lastHealthSampleAt({
    required String userId,
    required HealthMetric metric,
  });

  /// [metric] bucketed by **local** day, reconciled across sources.
  ///
  /// How the reconciliation works, and why it is not a plain `SUM`:
  ///
  /// - A [HealthMetric.isCumulative] metric is summed per source, then the
  ///   largest source total wins the day. The phone, the watch and a synced
  ///   third-party app all report steps for the same hours; adding them
  ///   together would multiply the user's step count by however many devices
  ///   they own. Taking the best-covered single source can undercount a day
  ///   split across devices, but it can never invent steps — the failure that
  ///   matters.
  /// - Everything else is averaged over the day's readings, which is the
  ///   meaningful summary of repeated point measurements.
  Future<List<HealthDailyValue>> getDailyHealth({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  });

  /// Erases every stored sample for [userId].
  ///
  /// Health data is device-only, so this is the whole delete — there is no
  /// server copy to chase. Backs the user-facing "forget my health data" and
  /// runs on sign-out.
  Future<void> deleteHealthSamples(String userId);
}
