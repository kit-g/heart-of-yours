import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'utils.dart';

typedef WorkoutId = String;

// Firestore collection
const _collectionId = 'workouts';

final _logger = Logger('Workouts');

class Workouts with ChangeNotifier implements SignOutStateSentry {
  final _db = FirebaseFirestore.instance;
  final _workouts = <WorkoutId, Workout>{};
  final ExerciseLookup lookForExercise;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  Workouts({
    required this.lookForExercise,
    this.onError,
  });

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(_collectionId);

  DocumentReference<Map<String, dynamic>>? get _activeWorkoutDoc {
    return switch (_activeWorkoutId) {
      WorkoutId id => _collection.doc(id),
      null => null,
    };
  }

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

  String? userId;

  WorkoutId? _activeWorkoutId;

  Workout? get activeWorkout => _workouts[_activeWorkoutId];

  bool _notifiedOfActiveWorkout = false;

  bool get hasActiveWorkout => _activeWorkoutId != null;

  bool get hasUnNotifiedActiveWorkout => hasActiveWorkout && !_notifiedOfActiveWorkout;

  set _activeWorkout(Workout? value) {
    if (value case Workout workout) {
      _activeWorkoutId = workout.id;
      _workouts[workout.id] = workout;
      notifyListeners();
    }
  }

  Future<void> init() async {
    if (userId case String userId) {
      _activeWorkout = await _getActiveWorkout(userId);
    }
  }

  Future<void> startWorkout({String? name}) async {
    final workout = Workout(name: name);
    _workouts[workout.id] = workout;
    _activeWorkoutId = workout.id;

    final doc = {
      'userId': userId,
      ...workout.toMap(),
    };

    _collection //
        .doc(workout.id)
        .set(doc)
        .catchError(
          (e, s) => _onError(e, stacktrace: s),
        );
    notifyListeners();
  }

  Future<void> cancelActiveWorkout() async {
    _workouts.remove(_activeWorkoutId);
    if (_activeWorkoutId case String id) {
      _collection.doc(id).delete();
    }
    _activeWorkoutId = null;
    notifyListeners();
  }

  Future<void>? startExercise(Exercise exercise) {
    activeWorkout?.startExercise(exercise);
    notifyListeners();
    return _syncSets();
  }

  Future<void>? _syncSets() {
    return _activeWorkoutDoc?. //
        update({'exercises': activeWorkout?.toMap()['exercises']}) //
        .catchError(
      (error, s) => _onError(error, stacktrace: s),
    );
  }

  void _forExercise(WorkoutExercise exercise, void Function(WorkoutExercise) action, {bool notifies = true}) {
    activeWorkout?.where((each) => each == exercise).forEach(action);
    if (notifies) {
      notifyListeners();
    }
  }

  void addEmptySet(WorkoutExercise exercise) {
    final empty = ExerciseSet(exercise.exercise);
    _forExercise(
      exercise,
      (each) => each.add(empty),
    );

    final doc = {
      'exercises.${exercise.id}.sets.${empty.id}': empty.toMap(),
    };
    _activeWorkoutDoc?.update(doc);
  }

  Future<void>? removeSet(WorkoutExercise exercise, ExerciseSet set) {
    _forExercise(
      exercise,
      (each) => each.remove(set),
    );

    final doc = {
      'exercises.${exercise.id}.sets.${set.id}': FieldValue.delete(),
    };
    return _activeWorkoutDoc?.update(doc);
  }

  Future<void>? removeExercise(WorkoutExercise exercise) {
    activeWorkout?.removeExercise(exercise);
    notifyListeners();

    final doc = {
      'exercises.${exercise.id}': FieldValue.delete(),
    };
    return _activeWorkoutDoc?.update(doc);
  }

  Future<void>? _markSet(WorkoutExercise exercise, ExerciseSet set, {required bool complete}) {
    _forExercise(
      exercise,
      (each) {
        for (var set in each.where((s) => set == s)) {
          set.completed = complete;
        }
      },
    );

    final updated = {
      'exercises.${exercise.id}.sets.${set.id}': set.toMap(),
    };
    return _activeWorkoutDoc?.update(updated);
  }

  Future<void>? markSetAsComplete(WorkoutExercise exercise, ExerciseSet set) {
    return _markSet(exercise, set, complete: true);
  }

  Future<void>? markSetAsIncomplete(WorkoutExercise exercise, ExerciseSet set) {
    return _markSet(exercise, set, complete: false);
  }

  void setWeight(WorkoutExercise exercise, ExerciseSet set, double? weight) {
    _forExercise(
      exercise,
      (each) {
        switch (set) {
          case WeightedSet s:
            s.weight = weight;
          case AssistedSet s:
            s.weight = weight;
          default:
        }
      },
      notifies: false,
    );
  }

  void setReps(WorkoutExercise exercise, ExerciseSet set, int? reps) {
    _forExercise(
      exercise,
      (each) {
        switch (set) {
          case SetForReps s:
            s.reps = reps;
          default:
        }
      },
      notifies: false,
    );
  }

  void swap(WorkoutExercise toInsert, WorkoutExercise after) {
    activeWorkout?.swap(toInsert, after);
    notifyListeners();
  }

  void append(WorkoutExercise exercise) {
    activeWorkout?.append(exercise);
    notifyListeners();
  }

  void renameWorkout(String name) {
    activeWorkout?.name = name;
    notifyListeners();
  }

  Future<Workout?> _getActiveWorkout(String userId) async {
    try {
      final querySnapshot = await _collection //
          .where('userId', isEqualTo: userId)
          .where('end', isNull: true)
          .withConverter(
            fromFirestore: _fromFirestore,
            toFirestore: (workout, _) => workout.toMap(),
          )
          .limit(1)
          .get();
      return querySnapshot.docs.firstOrNull?.data();
    } catch (error, s) {
      _onError(error, stacktrace: s);
      return null;
    }
  }

  void notifyOfActiveWorkout() {
    _notifiedOfActiveWorkout = true;
  }

  Workout _fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? _) {
    return Workout.fromJson(fromFirestoreMap(snapshot.data()!), lookForExercise);
  }

  void _onError(Object error, {stacktrace}) {
    _logger
      ..shout('${error.runtimeType}: $error')
      ..shout(stacktrace);

    onError?.call(error, stacktrace: stacktrace);
  }
}
