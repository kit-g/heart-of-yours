## Heart Health

Read-only access to the device's health store — Apple HealthKit on iOS, Google Health Connect on
Android — behind an interface the rest of the app can mock.

### The rule this package exists to keep

**Nothing read here goes to a server.** Health data is device-only by decision: not raw samples, not
derived aggregates, not weekly rollups. The OS store is already the system of record and already
survives a reinstall, so mirroring it up buys nothing but liability — and *"your health data never
leaves your device"* is a promise the app makes in its own copy.

See `docs/2026-08-02.wearables.md` for the full decision record.

### Why this package exists

- Keep the `health` plugin's vocabulary out of the app. Nothing outside `src/device.dart` mentions
  `HealthDataType`, so state and UI speak [`HealthMetric`] only — the same separation `heart_db`
  keeps between SQLite and the domain.
- Give `heart_state` an interface (`HealthService`) it can be tested against with no plugin, no
  platform channel and no device.
- Normalize units on ingest, so a stored row never carries a surprise.

### What it includes

- `HealthService` — the interface. Two implementations:
  - `DeviceHealthStore` — the real one, over the `health` plugin.
  - `UnsupportedHealthStore` — web and desktop; reads empty, claims nothing.
- `healthStore()` — picks the right one. Use this rather than constructing either.
- `HealthMetric` — the quantities we read, on our terms, with the unit each is stored in.
- `HealthSample` — one reading, faithful to the platform, including its `source`.

### Quick start

```dart
final health = healthStore();

if (await health.status() case HealthStoreStatus.available) {
  await health.requestAccess({HealthMetric.restingHeartRate, HealthMetric.bodyMass});

  final samples = await health.read(
    metrics: {HealthMetric.restingHeartRate},
    from: DateTime.now().subtract(const Duration(days: 90)),
    to: DateTime.now(),
  );
}
```

### Three things that will bite you

**1. iOS will not tell you whether read access was granted.** HealthKit deliberately refuses,
because "you may not read heart data" leaks that the user *has* heart data to hide. `requestAccess`
returns whether the *sheet was shown*, not whether anything was allowed, and `access()` returns
`HealthAccess.unknown` on iOS more or less always.

Consequence: **never render "Health connected ✓" from a permission check.** The only evidence access
exists is samples coming back. When none do, say "no data yet" — true whether the user declined or
simply hasn't worn a watch.

**2. Summing a cumulative metric double-counts.** HealthKit holds steps from the phone *and* the
watch *and* any third app, all covering the same hour. They are distinct readings, not duplicates,
so `removeDuplicates` does not touch them and a naive `sum` inflates the user's step count by
however many devices they own. Check `HealthMetric.isCumulative` and pick one source per window.

**3. HRV is not comparable across platforms.** Apple reports SDNN; Health Connect reports RMSSD.
Both are beat-to-beat variability in milliseconds, both collapse into `HealthMetric.heartRateVariability`,
and neither converts to the other — they routinely differ by a factor of two. `isPlatformDependent`
flags it. A chart must not plot one against the other, and a narrative must not describe a user
switching phones as a change in their body.

### Relationship to the other packages

- `heart_models` — **deliberately not a dependency.** Health data has no backend component, and
  `heart_models` lives in the heart-go repo behind a git ref; keeping it out means this package can
  change without a cross-repo release.
- `heart_db` — persists `HealthSample.toRow()` into `health_samples`. That map's keys must match the
  table's columns exactly; the round-trip test in `test/heart_health_test.dart` is the tripwire.
- `heart_state` — owns the `Health` notifier that drives sync and exposes samples to the UI.

### Adding a metric

1. A case in `HealthMetric`, with its unit, plus `fromString` and `isCumulative`.
2. A case in `_dataType` and `_metricOf` in `src/device.dart`.
3. A case in `_unitMatches` if the unit is new.

The compiler finds all three — every switch over `HealthMetric` is exhaustive.
