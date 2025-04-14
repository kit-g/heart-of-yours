import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

typedef WorkoutId = String;

class Workouts with ChangeNotifier implements SignOutStateSentry {
  final _workouts = <WorkoutId, Workout>{};
  final ExerciseLookup lookForExercise;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final WorkoutService _localService;
  final RemoteWorkoutService _remoteService;

  Workouts({
    required this.lookForExercise,
    required WorkoutService service,
    required RemoteWorkoutService remoteService,
    this.onError,
  })  : _localService = service,
        _remoteService = remoteService;

  // CollectionReference<Map<String, dynamic>> get _collection => _db.collection(_collectionId);

  @override
  void onSignOut() {
    _workouts.clear();
    _activeWorkoutId = null;
    userId = null;
    historyInitialized = false;
    _notifiedOfActiveWorkout = false;
    _latestMarkedSet = null;
  }

  static Workouts of(BuildContext context) {
    return Provider.of<Workouts>(context, listen: false);
  }

  static Workouts watch(BuildContext context) {
    return Provider.of<Workouts>(context, listen: true);
  }

  String? userId;

  WorkoutId? _activeWorkoutId;

  bool historyInitialized = false;

  Workout? get activeWorkout => _workouts[_activeWorkoutId];

  bool _notifiedOfActiveWorkout = false;

  bool get hasActiveWorkout => _activeWorkoutId != null;

  bool get hasUnNotifiedActiveWorkout => hasActiveWorkout && !_notifiedOfActiveWorkout;

  Iterable<Workout> get history => _workouts.values.where((workout) => workout.isCompleted);

  (WorkoutExercise exercise, ExerciseSet set)? _latestMarkedSet;

  (WorkoutExercise, ExerciseSet)? get nextIncomplete {
    return switch (_latestMarkedSet) {
      (WorkoutExercise exercise, ExerciseSet set) => activeWorkout?.nextIncomplete(exercise, set),
      null => null,
    };
  }

  set _activeWorkout(Workout? value) {
    if (value case Workout workout) {
      _activeWorkoutId = workout.id;
      _workouts[workout.id] = workout;
    } else {
      _activeWorkoutId = null;
    }
    notifyListeners();
  }

  ExerciseId? _pointedAtExercise;

  ExerciseId? get pointedAtExercise => _pointedAtExercise;

  set pointedAtExercise(ExerciseId? value) {
    _pointedAtExercise = value;
    notifyListeners();
  }

  Future<void> pointAt(ExerciseId exerciseId) {
    pointedAtExercise = exerciseId;
    return Future.delayed(const Duration(milliseconds: 300), () => pointedAtExercise = null);
  }

  Future<void> init() async {
    if (userId case String userId) {
      _activeWorkout = await _getActiveWorkout(userId);
    }
  }

  Future<void> fetchWorkout(String workoutId) async {
    if (userId case String userId) {
      final workout = await _localService.getWorkout(userId, workoutId);
      if (workout != null) {
        _workouts[workoutId] = workout;
        notifyListeners();
      }
    }
  }

  Future<void> startWorkout({String? name, Workout? template}) {
    assert(name == null || template == null, 'Pass only the name or the full workout');
    final workout = template ?? Workout(name: name);
    workout.end = null;
    _workouts[workout.id] = workout;
    _activeWorkoutId = workout.id;

    notifyListeners();
    return _localService.startWorkout(workout, userId!);
  }

  Future<void> finishActiveWorkout() async {
    activeWorkout?.finish(DateTime.timestamp());

    final active = activeWorkout;
    if (active == null) return;

    await saveWorkout(active);
    _activeWorkout = null;
  }

  Future<void> saveWorkout(Workout active) {
    _localService.finishWorkout(active, userId!);

    _workouts[active.id] = active;
    notifyListeners();

    return _remoteService.saveWorkout(active);
  }

  Future<void> cancelActiveWorkout() async {
    _workouts.remove(_activeWorkoutId);
    if (_activeWorkoutId case String id) {
      _deleteWorkout(id).catchError(
        (error, stacktrace) {
          onError?.call(error, stacktrace: stacktrace);
        },
      );
      _localService.deleteWorkout(id);
    }
    _activeWorkoutId = null;
    notifyListeners();
  }

  Future<void> _deleteWorkout(String workoutId) {
    return _remoteService.deleteWorkout(workoutId);
  }

  Future<void> deleteWorkout(String workoutId) {
    _workouts.remove(workoutId);
    notifyListeners();
    _localService.deleteWorkout(workoutId);
    return _deleteWorkout(workoutId);
  }

  Future<void> startExercise(Exercise exercise) async {
    if (activeWorkout case Workout workout) {
      final starter = workout.add(exercise);
      notifyListeners();
      return _localService.startExercise(workout.id, starter);
    }
  }

  void _forExercise(WorkoutExercise exercise, void Function(WorkoutExercise) action, {bool notifies = true}) {
    activeWorkout?.where((each) => each == exercise).forEach(action);
    if (notifies) {
      notifyListeners();
    }
  }

  /// adds a new set to this exercise
  /// tries to copy the previous set
  /// or makes an empty one
  Future<void>? addSet(WorkoutExercise exercise) {
    final set = exercise.lastOrNull?.copy() ?? ExerciseSet(exercise.exercise);
    _forExercise(
      exercise,
      (each) => each.add(set),
    );

    return _localService.addSet(exercise, set);
  }

  Future<void>? removeSet(WorkoutExercise exercise, ExerciseSet set) {
    _forExercise(
      exercise,
      (each) => each.remove(set),
    );

    return _localService.removeSet(set);
  }

  Future<void>? removeExercise(WorkoutExercise exercise) {
    activeWorkout?.remove(exercise);
    notifyListeners();

    return _localService.removeExercise(exercise);
  }

  Future<void>? markSetAsComplete(WorkoutExercise exercise, ExerciseSet set) {
    set.isCompleted = true;
    _latestMarkedSet = (exercise, set);
    notifyListeners();
    return _localService.markSetAsComplete(set);
  }

  Future<void>? markSetAsIncomplete(WorkoutExercise exercise, ExerciseSet set) {
    set.isCompleted = false;
    notifyListeners();
    return _localService.markSetAsIncomplete(set);
  }

  Future<void> storeMeasurements(ExerciseSet set) {
    return _localService.storeMeasurements(set);
  }

  Future<void>? swap(WorkoutExercise toInsert, WorkoutExercise after) async {
    activeWorkout?.swap(toInsert, after);
    notifyListeners();
  }

  Future<void>? append(WorkoutExercise exercise) async {
    activeWorkout?.append(exercise);
    notifyListeners();
  }

  Future<void>? renameWorkout(String name) async {
    activeWorkout?.name = name;
    if (activeWorkout case Workout workout) {
      _localService.renameWorkout(workoutId: workout.id, name: name);
    }
    notifyListeners();
  }

  Future<Workout?> _getActiveWorkout(String userId) async {
    try {
      return _localService.getActiveWorkout(userId);
    } catch (error, s) {
      onError?.call(error, stacktrace: s);
      return null;
    }
  }

  Future<Iterable<Workout>?> _getRemoteHistory(String userId, {int pageSize = 10}) async {
    try {
      return _remoteService.getWorkouts(lookForExercise, pageSize: pageSize);
    } catch (error, s) {
      onError?.call(error, stacktrace: s);
      return null;
    }
  }

  Future<void> initHistory() async {
    if (userId case String id) {
      final local = await _localService.getWorkoutHistory(id);
      if (local case Iterable<Workout> local when local.isNotEmpty) {
        _workouts.addAll(Map.fromEntries(local.map(_entry)));
      } else {
        final workouts = await _getRemoteHistory(id);
        if (workouts != null) {
          _localService.storeWorkoutHistory(workouts, id);
          _workouts.addAll(Map.fromEntries(workouts.map(_entry)));
        }
      }
      historyInitialized = true;
      notifyListeners();
    }
  }

  static MapEntry<WorkoutId, Workout> _entry(Workout w) => MapEntry(w.id, w);

  void notifyOfActiveWorkout() {
    _notifiedOfActiveWorkout = true;
  }

  Workout? lookup(String id) => _workouts[id];
}
