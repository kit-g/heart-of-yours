import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Exercises with ChangeNotifier, Iterable<Exercise> implements SignOutStateSentry {
  final bool isCached;
  final _db = FirebaseFirestore.instance;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final _selectedExercises = <Exercise>{};
  final ExerciseService _service;
  final _filters = <ExerciseFilter>{};

  Exercises({
    this.isCached = true,
    this.onError,
    required ExerciseService service,
  }) : _service = service;

  bool isInitialized = false;

  final _exercises = <ExerciseId, Exercise>{};

  String? userId;

  @override
  void onSignOut() {
    isInitialized = false;
    _exercises.clear();
    _selectedExercises.clear();
  }

  @override
  Iterator<Exercise> get iterator => _exercises.values.iterator;

  Iterable<ExerciseFilter> get filters => _filters;

  Iterable<ExerciseFilter> get categories => _filters.whereType<Category>();

  Iterable<ExerciseFilter> get targets => _filters.whereType<Target>();

  Exercise operator [](int index) => _exercises.values.toList()[index];

  static Exercises of(BuildContext context) {
    return Provider.of<Exercises>(context, listen: false);
  }

  static Exercises watch(BuildContext context) {
    return Provider.of<Exercises>(context, listen: true);
  }

  Future<void> init() async {
    try {
      final (_, local) = await _service.getExercises();

      if (local.isNotEmpty) {
        _exercises.addAll(Map.fromEntries(local.map((each) => MapEntry(each.name, each))));
        isInitialized = true;
        notifyListeners();
        return;
      }

      final options = GetOptions(source: isCached ? Source.cache : Source.serverAndCache);
      final all = await _db //
          .collection('exercises')
          .withConverter<Exercise>(
            fromFirestore: _fromFirestore,
            toFirestore: (exercise, _) => exercise.toMap(),
          )
          .get(options);

      _exercises.addAll(Map.fromEntries(all.docs.map(_snapshot)));
      _service.storeExercises(_exercises.values);
      isInitialized = true;
      notifyListeners();
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  Iterable<Exercise> search(String query, {bool filters = false}) {
    bool fitsSearch(Exercise exercise) {
      return exercise.contains(query) && (filters ? exercise.fits(_filters) : true);
    }

    return _exercises.values.where(fitsSearch);
  }

  Exercise? lookup(ExerciseId id) {
    return _exercises[id];
  }

  Iterable<Exercise> get selected => _selectedExercises;

  void select(Exercise exercise) {
    _selectedExercises.add(exercise);
    notifyListeners();
  }

  void deselect(Exercise exercise) {
    _selectedExercises.remove(exercise);
    notifyListeners();
  }

  bool hasSelected(Exercise exercise) {
    return _selectedExercises.contains(exercise);
  }

  void unselectAll() {
    _selectedExercises.clear();
    notifyListeners();
  }

  void addFilter(ExerciseFilter filter) {
    _filters.add(filter);
    notifyListeners();
  }

  void removeFilter(ExerciseFilter filter) {
    _filters.remove(filter);
    notifyListeners();
  }

  Future<Iterable<ExerciseAct>> getExerciseHistory(Exercise exercise, {int? pageSize, String? anchor}) async {
    if (userId case String id) {
      return _service.getExerciseHistory(id, exercise, pageSize: pageSize, anchor: anchor);
    }
    return [];
  }

  Future<Map?> getExerciseRecords(Exercise exercise) async {
    if (userId case String id) {
      return _service.getRecord(id, exercise);
    }
    return null;
  }

  Future<List<(num, DateTime)>?> getRepsHistory(Exercise exercise) async {
    if (userId case String id) {
      return _service.getRepsHistory(id, exercise, limit: _exerciseHistoryLimit);
    }
    return null;
  }

  Future<List<(num, DateTime)>?> getDistanceHistory(Exercise exercise) async {
    if (userId case String id) {
      return _service.getDistanceHistory(id, exercise, limit: _exerciseHistoryLimit);
    }
    return null;
  }

  Future<List<(num, DateTime)>?> getDurationHistory(Exercise exercise) async {
    if (userId case String id) {
      return _service.getDurationHistory(id, exercise, limit: _exerciseHistoryLimit);
    }
    return null;
  }

  Future<List<(num, DateTime)>?> getWeightHistory(Exercise exercise) async {
    if (userId case String id) {
      return _service.getWeightHistory(id, exercise, limit: _exerciseHistoryLimit);
    }
    return null;
  }
}

MapEntry<ExerciseId, Exercise> _snapshot(QueryDocumentSnapshot<Exercise> snapshot) {
  final exercise = snapshot.data();
  return MapEntry(exercise.name, exercise);
}

Exercise _fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? _) {
  return Exercise.fromJson(snapshot.data()!);
}

const _exerciseHistoryLimit = 30;
