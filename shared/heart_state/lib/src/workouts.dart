import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

import 'utils.dart';

typedef WorkoutId = String;

// Firestore collection
const _collectionId = 'workouts';

class Workouts with ChangeNotifier implements SignOutStateSentry {
  final _db = FirebaseFirestore.instance;
  final _workouts = <WorkoutId, Workout>{};
  final ExerciseLookup lookForExercise;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final bool isCached;
  final GetOptions _options;
  final WorkoutService _service;

  Workouts({
    required this.lookForExercise,
    required WorkoutService service,
    this.onError,
    this.isCached = false,
  })  : _options = GetOptions(source: isCached ? Source.cache : Source.serverAndCache),
        _service = service;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(_collectionId);

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
      final workout = await _service.getWorkout(userId, workoutId);
      if (workout != null) {
        _workouts[workoutId] = workout;
        notifyListeners();
      }
    }
  }

  Future<void> startWorkout({String? name, Workout? template}) {
    assert(name == null || template == null, 'Pass only the name or the full workout');
    final workout = template ?? Workout(name: name);
    _workouts[workout.id] = workout;
    _activeWorkoutId = workout.id;

    notifyListeners();
    return _service.startWorkout(workout, userId!);
  }

  Future<void> finishActiveWorkout() async {
    activeWorkout?.finish(DateTime.timestamp());

    final active = activeWorkout;
    if (active == null) return;

    await saveWorkout(active);
    _activeWorkout = null;
  }

  Future<void> saveWorkout(Workout active) {
    _service.finishWorkout(active, userId!);

    _workouts[active.id] = active;
    notifyListeners();
    final aggregation = _db.collection('aggregations').doc(userId!);

    return _db.runTransaction<void>(
      (transaction) async {
        final aggregationSnapshot = await transaction.get(aggregation);
        final currentAggregations = switch (aggregationSnapshot.data()?['workouts']) {
          Map existing => existing,
          _ => <String, dynamic>{},
        };
        final currentWeek = switch (currentAggregations[active.weekOf()]) {
          Map m => m,
          _ => <String, String?>{},
        };
        final updated = currentWeek.take(_maxWorkoutBars)..addAll(active.toSummary().toMap());

        transaction
          ..set(
            _collection.doc(active.id),
            {
              'userId': userId,
              ...active.toMap(),
            },
          )
          ..set(
            aggregation,
            {
              'workouts': {active.weekOf(): updated}
            },
            SetOptions(merge: true),
          );
      },
    ).catchError(
      (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      },
    );
  }

  Future<void> cancelActiveWorkout() async {
    _workouts.remove(_activeWorkoutId);
    if (_activeWorkoutId case String id) {
      _deleteWorkout(id).catchError(
        (error, stacktrace) {
          switch (error) {
            case FirebaseException(:var code) when code == 'permission-denied':
              return;
            // ok in this case, since the workout might not be in Firebase
            default:
              onError?.call(error, stacktrace: stacktrace);
          }
        },
      );
      _service.deleteWorkout(id);
    }
    _activeWorkoutId = null;
    notifyListeners();
  }

  Future<void> _deleteWorkout(String workoutId) {
    return _collection.doc(workoutId).delete();
  }

  Future<void> deleteWorkout(String workoutId) {
    _workouts.remove(workoutId);
    notifyListeners();
    _service.deleteWorkout(workoutId);
    _deleteAggregation(workoutId);
    return _deleteWorkout(workoutId);
  }

  Future<void> _deleteAggregation(String workoutId) async {
    if (userId case String id) {
      var doc = {
        'workouts.${deSanitizeId(workoutId).mondayKey()}.$workoutId': FieldValue.delete(),
      };
      return _db.collection('aggregations').doc(id).update(doc);
    }
  }

  Future<void> startExercise(Exercise exercise) async {
    if (activeWorkout case Workout workout) {
      final starter = workout.add(exercise);
      notifyListeners();
      return _service.startExercise(workout.id, starter);
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

    return _service.addSet(exercise, set);
  }

  Future<void>? removeSet(WorkoutExercise exercise, ExerciseSet set) {
    _forExercise(
      exercise,
      (each) => each.remove(set),
    );

    return _service.removeSet(set);
  }

  Future<void>? removeExercise(WorkoutExercise exercise) {
    activeWorkout?.remove(exercise);
    notifyListeners();

    return _service.removeExercise(exercise);
  }

  Future<void>? markSetAsComplete(WorkoutExercise exercise, ExerciseSet set) {
    set.isCompleted = true;
    _latestMarkedSet = (exercise, set);
    notifyListeners();
    return _service.markSetAsComplete(set);
  }

  Future<void>? markSetAsIncomplete(WorkoutExercise exercise, ExerciseSet set) {
    set.isCompleted = false;
    notifyListeners();
    return _service.markSetAsIncomplete(set);
  }

  Future<void> storeMeasurements(ExerciseSet set) {
    return _service.storeMeasurements(set);
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
      _service.renameWorkout(workoutId: workout.id, name: name);
    }
    notifyListeners();
  }

  Future<Workout?> _getActiveWorkout(String userId) async {
    try {
      final local = await _service.getActiveWorkout(userId);

      if (local != null) return local;
      final querySnapshot = await _collection
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
      onError?.call(error, stacktrace: s);
      return null;
    }
  }

  Future<Iterable<Workout>?> _getRemoteHistory(String userId, {int pageSize = 7}) async {
    try {
      final querySnapshot = await _collection //
          .where('userId', isEqualTo: userId)
          .where('end', isNull: false)
          .orderBy('end', descending: true)
          .withConverter(
            fromFirestore: _fromFirestore,
            toFirestore: (workout, _) => workout.toMap(),
          )
          .limit(pageSize)
          .get(_options);
      return querySnapshot.docs.map((doc) => doc.data());
    } catch (error, s) {
      onError?.call(error, stacktrace: s);
      return null;
    }
  }

  Future<void> initHistory() async {
    if (userId case String id) {
      final local = await _service.getWorkoutHistory(id);
      if (local case Iterable<Workout> local when local.isNotEmpty) {
        _workouts.addAll(Map.fromEntries(local.map(_entry)));
      } else {
        final workouts = await _getRemoteHistory(id);
        if (workouts != null) {
          _service.storeWorkoutHistory(workouts, id);
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

  Workout _fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? _) {
    return Workout.fromJson(fromFirestoreMap(snapshot.data()!), lookForExercise);
  }

  Workout? lookup(String id) => _workouts[id];
}

// how many weeks of workouts the chart will display
const _maxWorkoutBars = 8;

extension on String {
  DateTime? mondayOf() {
    try {
      return getMonday(DateTime.parse(this));
    } on FormatException {
      return null;
    }
  }

  String? mondayKey() {
    return switch (mondayOf()) {
      DateTime dt => sanitizeId(dt),
      null => null,
    };
  }
}

extension _E<K, V> on Map<K, V> {
  Map<K, V> take(int count) {
    return Map.fromEntries(entries.take(count));
  }
}
