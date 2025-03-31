import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class PreviousExercises with ChangeNotifier implements SignOutStateSentry {
  final _previous = <ExerciseId, List<Map<String, dynamic>>>{};

  final PreviousExerciseService _service;
  String? userId;

  PreviousExercises({required PreviousExerciseService service}) : _service = service;

  @override
  void onSignOut() {
    _previous.clear();
  }

  static PreviousExercises of(BuildContext context) {
    return Provider.of<PreviousExercises>(context, listen: false);
  }

  static PreviousExercises watch(BuildContext context) {
    return Provider.of<PreviousExercises>(context, listen: true);
  }

  Future<void> init() async {
    if (userId case String id) {
      final previous = await _service.getPreviousSets(id);
      _previous
        ..clear()
        ..addAll(previous);
      notifyListeners();
    }
  }

  Map<String, dynamic>? at(ExerciseId exerciseId, int index) {
    try {
      return _previous[exerciseId]?[index];
    } on RangeError {
      return null;
    }
  }

  Map<String, dynamic>? last(ExerciseId exerciseId) {
    return _previous[exerciseId]?.lastOrNull;
  }
}