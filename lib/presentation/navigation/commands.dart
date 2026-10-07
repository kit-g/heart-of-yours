import 'package:heart/core/env/watch.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart/presentation/widgets/workout/rest.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart' show finishWorkout, pauseActiveWorkout;
import 'package:heart_models/heart_models.dart' hide Health;
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// What became of a [WatchCommand] applied to the active workout.
enum CommandOutcome {
  /// Applied; the state that results is the answer.
  applied,

  /// A set was ticked, with its rest started.
  ticked,

  /// Nothing to apply it to: another workout, one that is over, or a set it
  /// names that is gone or already done. Whoever sent it hears the state as
  /// it is.
  stale,

  /// The workout was finished. The finish's own flow answers — the summary,
  /// and "no workout" to every surface — so there is no state to send back.
  finished,
}

/// Applies [command] the way the same tap on the phone would (#141): the one
/// applier for every second actor — the watch (#183) and the lock screen —
/// which are requests, never edits. The phone is the only writer; each actor
/// learns the outcome from the state it is sent afterwards, never by
/// guessing. A command about a workout that is over, or another one, changes
/// nothing.
///
/// [context] is any below the app's providers and localizations: the rest it
/// starts needs the notification copy.
CommandOutcome applyWorkoutCommand(BuildContext context, WatchCommand command) {
  final workouts = Workouts.of(context);
  final workout = workouts.activeWorkout;
  if (workout == null || workout.id != command.workoutId) return .stale;

  switch (command) {
    case WatchComplete(:final setId, :final weight, :final reps, :final at):
      return switch (_complete(context, workouts, workout, setId, weight: weight, reps: reps, at: at)) {
        true => .ticked,
        false => .stale,
      };
    case WatchEditSet(:final setId, :final weight, :final reps):
      // new values for a set gone back to; it keeps its tick
      if (_find(workout, setId) case (WorkoutExercise exercise, ExerciseSet set)) {
        workouts.editSet(set, weight: kilogramsOf(context, exercise, weight), reps: reps);
        return .applied;
      }
      return .stale;
    case WatchUntickSet(:final setId):
      if (_find(workout, setId) case (WorkoutExercise exercise, ExerciseSet set) when set.isCompleted) {
        workouts.markSetAsIncomplete(exercise, set);
        return .applied;
      }
      return .stale;
    case WatchSkipRest():
      final alarms = Alarms.of(context);
      if (alarms.remainsInActiveExercise == null) return .stale;
      alarms.stopActiveExerciseTimer();
      return .applied;
    // placed when it happened on the wrist, which a queue may have held for
    // a while; the watch offers neither while pausing is off (#134)
    case WatchPauseWorkout(:final at) when Preferences.of(context).isOn(.pauseWorkout):
      pauseActiveWorkout(context, at: at);
      return .applied;
    case WatchPauseWorkout():
      return .stale;
    case WatchResumeWorkout(:final at):
      workouts.resume(at: at);
      return .applied;
    case WatchFinishWorkout(:final at):
      // the watch offers Finish only with nothing left to tick; if a set was
      // added on the phone since, that is the phone's to finish
      if (workout.isValid && upNextIn(workout, after: workouts.latestMarkedSet)?.set == null) {
        // the phone's own finish: it saves, writes Health, shows the summary,
        // and the state it leaves — no workout — is what every surface hears
        // next — ended when the user confirmed it, which a Finish queued while
        // the phone was out of reach (#206) says was a while ago
        finishWorkout(context, workouts, at: at);
        return .finished;
      }
      return .stale;
    case WatchStartRest(:final seconds, :final at):
      // the exercise the user is on: the one the next set belongs to, or the
      // last one once every set is done
      final exercise = upNextIn(workout, after: workouts.latestMarkedSet)?.exercise ?? workout.lastOrNull;
      if (exercise == null) return .stale;
      final length = seconds ?? Timers.of(context)[exercise.exercise.id];
      if (length == null) return .stale;
      // placed when it was asked for, which a queue may have held a while;
      // one that would already be over does not start at all
      final total = switch (at) {
        DateTime at => length - DateTime.now().difference(at).inSeconds.clamp(0, length),
        null => length,
      };
      if (total <= 0) return .stale;
      Alarms.of(context).startActiveExerciseTimer(
        total,
        exerciseId: exercise.id,
        scheduleNotification: (when) => scheduleRestNotification(context, exercise, when),
      );
      return .applied;
    case WatchAdjustRest(:final seconds):
      final alarms = Alarms.of(context);
      if (alarms.remainsInActiveExercise == null) return .stale;
      final resting = workout.where((exercise) => exercise.id == alarms.activeExerciseId).firstOrNull;
      alarms.adjustActiveExerciseTime(
        seconds,
        rescheduleNotification: switch (resting) {
          WorkoutExercise exercise => (when) => scheduleRestNotification(context, exercise, when),
          null => null,
        },
      );
      return .applied;
  }
}

/// Ticks [setId] the way the set row's tick does (`set_item.dart`): the
/// values the actor showed become the set's, converted from the unit they
/// were shown in, and the exercise's rest starts — without the countdown
/// dialog, which nobody is looking at.
bool _complete(
  BuildContext context,
  Workouts workouts,
  Workout workout,
  String setId, {
  double? weight,
  int? reps,
  DateTime? at,
}) {
  // gone, or ticked already (a double tap, or the phone got there first)
  if (_find(workout, setId) case (WorkoutExercise exercise, ExerciseSet set) when !set.isCompleted) {
    if (weight != null || reps != null) {
      workouts.editSet(set, weight: kilogramsOf(context, exercise, weight), reps: reps);
    }
    if (set.canBeCompleted) {
      workouts.markSetAsComplete(exercise, set, at: at);
      startRest(context, exercise, since: at);
      return true;
    }
  }
  return false;
}

(WorkoutExercise, ExerciseSet)? _find(Workout workout, String setId) {
  return workout
      .expand((exercise) => exercise.map((set) => (exercise, set)))
      .where((pair) => pair.$2.id == setId)
      .firstOrNull;
}

/// The unit [exercise] is shown in: its own override, or the app's.
MeasurementUnit unitOf(BuildContext context, WorkoutExercise exercise) {
  return Exercises.of(context).unitFor(exercise.exercise.id) ?? Preferences.of(context).weightUnit;
}

/// A weight an actor sent, in the unit it was shown in, as stored.
double? kilogramsOf(BuildContext context, WorkoutExercise exercise, double? weight) {
  return switch ((weight, unitOf(context, exercise))) {
    (double weight, .imperial) => weight.asKilograms,
    (double weight, .metric) => weight,
    (null, _) => null,
  };
}
