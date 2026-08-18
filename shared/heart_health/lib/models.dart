/// The health domain types, with no platform behind them.
///
/// A separate library from `heart_health.dart` so persistence can depend on the
/// vocabulary without dragging in the `health` plugin: `heart_db` stores a
/// [HealthSample] but never reads one off a device, and its tests should not
/// need a platform channel to run.
///
/// Importing `heart_health.dart` gives you all of this plus the store.
library;

part 'src/activity.dart';
part 'src/metric.dart';
part 'src/sample.dart';
part 'src/store_contract.dart';
