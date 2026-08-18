/// Access to the device's health store — HealthKit on iOS, Health Connect on
/// Android. Six metrics read; one thing written, the workout the user just
/// finished.
///
/// **Health data read through this package is device-only.** It is never sent
/// to heart-api: not raw samples, not aggregates, not rollups. The OS store is
/// already the system of record and already survives a reinstall, so mirroring
/// it to a server buys nothing but liability — and "never leaves your device"
/// is a promise the app makes in its own copy. See `docs/2026-08-02.wearables.md`.
///
/// Start at [HealthService]; get one with `healthStore()`. Code that only needs
/// the vocabulary — [HealthMetric], [HealthSample] — should import
/// `models.dart` instead and stay free of the plugin.
library;

import 'models.dart';

export 'models.dart';
export 'src/store.dart';

part 'src/service.dart';
part 'src/unsupported.dart';
