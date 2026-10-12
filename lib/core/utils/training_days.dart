import 'package:heart_models/heart_models.dart';

/// One calendar day of training, as the Home Screen widget (#161) counts it:
/// [volume] in kilograms, [seconds] trained, and the sets and reps the user
/// ticked off. Warm-ups are left out, as they are from records and the muscle
/// map (#236): they ready a muscle for the work, and these count the work.
typedef TrainingDay = ({double volume, int workouts, int seconds, int sets, int reps});

/// [workouts] finished on or after [since], per local calendar day, keyed by
/// that day's midnight. A workout belongs to the day it started, as it does to
/// the week it started in everywhere else. Days without one are absent.
///
/// Volume is what the history card calls total volume: weight × reps of the
/// loaded categories.
Map<DateTime, TrainingDay> trainingDays(Iterable<Workout> workouts, {required DateTime since}) {
  final days = <DateTime, TrainingDay>{};
  for (final workout in workouts.where((workout) => workout.isCompleted)) {
    final start = workout.start.toLocal();
    if (start.isBefore(since)) continue;
    final day = DateTime(start.year, start.month, start.day);
    final sets = workout.expand((exercise) => exercise).where((set) => set.isCompleted && set.setType != .warmup);
    final today = days[day] ?? (volume: 0.0, workouts: 0, seconds: 0, sets: 0, reps: 0);
    days[day] = (
      volume: today.volume + sets.map(_volume).fold(0.0, (sum, each) => sum + each),
      workouts: today.workouts + 1,
      seconds: today.seconds + (workout.duration?.inSeconds ?? 0),
      sets: today.sets + sets.length,
      reps: today.reps + sets.map((set) => set.reps ?? 0).fold(0, (sum, each) => sum + each),
    );
  }
  return days;
}

double _volume(ExerciseSet set) {
  return switch (set.category) {
    .barbell || .dumbbell || .machine || .weightedBodyWeight || .assistedBodyWeight => set.total ?? 0,
    .repsOnly || .cardio || .duration || .weightedDistance || .weightedDuration => 0,
  };
}
