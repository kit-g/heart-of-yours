import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

typedef WorkoutId = String;

class Workouts with ChangeNotifier implements SignOutStateSentry {
  final String? userId;
  final _db = FirebaseFirestore.instance;
  final _workouts = <WorkoutId, Workout>{};

  Workouts({this.userId});

  @override
  void onSignOut() {
    _workouts.clear();
    _activeWorkoutId = null;
  }

  static Workouts of(BuildContext context) {
    return Provider.of<Workouts>(context, listen: false);
  }

  static Workouts watch(BuildContext context) {
    return Provider.of<Workouts>(context, listen: true);
  }

  WorkoutId? _activeWorkoutId;

  Workout? get activeWorkout => _workouts[_activeWorkoutId];

  bool get hasActiveWorkout => _activeWorkoutId != null;

  set activeWorkoutId(WorkoutId? value) {
    _activeWorkoutId = value;
    notifyListeners();
  }

  Future<void> startWorkout({String? name}) async {
    final workout = Workout(name: name);
    _workouts[workout.id] = workout;
    _activeWorkoutId = workout.id;
    notifyListeners();
  }

  void cancelActiveWorkout() {
    _workouts.remove(_activeWorkoutId);
    _activeWorkoutId = null;
    notifyListeners();
  }

  void startExercise(Exercise exercise) {
    activeWorkout?.startExercise(exercise);
    notifyListeners();
  }

  void _forExercise(WorkoutExercise exercise, void Function(WorkoutExercise) action) {
    activeWorkout?.where((each) => each == exercise).forEach(action);
    notifyListeners();
  }

  void addEmptySet(WorkoutExercise exercise) {
    _forExercise(
      exercise,
      (each) => each.add(ExerciseSet(exercise.exercise)),
    );
  }

  void removeSet(WorkoutExercise exercise, ExerciseSet set) {
    _forExercise(
      exercise,
      (each) => each.remove(set),
    );
  }

  void _markSet(WorkoutExercise exercise, ExerciseSet set, {required bool complete}) {
    _forExercise(
      exercise,
      (each) {
        for (var set in each.where((s) => set == s)) {
          set.completed = complete;
        }
      },
    );
  }

  void markSetAsComplete(WorkoutExercise exercise, ExerciseSet set) {
    _markSet(exercise, set, complete: true);
  }

  void markSetAsIncomplete(WorkoutExercise exercise, ExerciseSet set) {
    _markSet(exercise, set, complete: false);
  }
}