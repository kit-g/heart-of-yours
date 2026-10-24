import 'dart:math' as math;

import 'package:heart_models/heart_models.dart';

/// One rung of a warm-up ramp (#158): a share of the working weight, in
/// percent, and the reps done with it.
typedef WarmupStep = ({int percent, int reps});

/// A warm-up set to add: [weight] in kilograms, as a set stores it.
typedef WarmupSet = ({double weight, int reps});

/// The ramp until the user sets their own: 40% × 5, 60% × 3, 80% × 1.
const defaultWarmupScheme = <WarmupStep>[
  (percent: 40, reps: 5),
  (percent: 60, reps: 3),
  (percent: 80, reps: 1),
];

/// The most rungs a ramp holds. Past this it is a workout of its own.
const maxWarmupSteps = 6;

/// Whether [step] can be a rung: a share under the working weight — a warm-up
/// at 100% is a working set — and a count of reps someone would warm up with.
bool isWarmupStep(WarmupStep step) {
  return switch (step) {
    (percent: >= 1 && <= 99, reps: >= 1 && <= 30) => true,
    _ => false,
  };
}

/// Whether [category] is warmed up to (#158): a load on a bar or a stack,
/// which climbs by plates.
bool warmsUp(Category category) {
  return switch (category) {
    .barbell || .machine => true,
    .dumbbell ||
    .weightedBodyWeight ||
    .assistedBodyWeight ||
    .repsOnly ||
    .cardio ||
    .duration ||
    .weightedDistance ||
    .weightedDuration => false,
  };
}

/// The warm-ups [scheme] makes of a [working] weight, in kilograms, of a
/// [category] exercise whose weights are read in [unit].
///
/// Each is rounded in [unit] to the nearest 2.5 kg or 5 lb — what a pair of
/// plates adds — and never under the empty bar (20 kg, 45 lb), or one step on
/// a machine. Each is heavier than the one before it and lighter than
/// [working]: rungs that round onto the bar together, or up to the working
/// weight, are left out, so a light working set gets fewer warm-ups, or none.
List<WarmupSet> warmupSets({
  required double working,
  required Category category,
  required MeasurementUnit unit,
  required Iterable<WarmupStep> scheme,
}) {
  if (!warmsUp(category) || working <= 0) return const [];
  final (step, bar) = switch (unit) {
    .metric => (2.5, 20.0),
    .imperial => (5.0, 45.0),
  };
  final floor = category == .barbell ? bar : step;
  final shown = switch (unit) {
    .metric => working,
    .imperial => working.asPounds,
  };
  final rungs = scheme.where(isWarmupStep).toList()..sort((a, b) => a.percent.compareTo(b.percent));

  final ramp = rungs.fold(<({double load, int reps})>[], (ramp, rung) {
    final load = math.max((shown * rung.percent / 100 / step).round() * step, floor);
    final rises = ramp.isEmpty || load > ramp.last.load;
    // a hair under: a pound weight read back from kilograms is not exact
    final under = load < shown - .01;
    return rises && under ? [...ramp, (load: load, reps: rung.reps)] : ramp;
  });

  return [
    for (final (:load, :reps) in ramp)
      (
        weight: switch (unit) {
          .metric => load,
          .imperial => load.asKilograms,
        },
        reps: reps,
      ),
  ];
}
