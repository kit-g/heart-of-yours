import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Timers with ChangeNotifier implements SignOutStateSentry {
  final TimersService _service;

  final _timers = <String, int>{};

  String? userId;

  new({required this._service});

  @override
  void onSignOut() {
    userId = null;
    _timers.clear();
  }

  static Timers of(BuildContext context) {
    return Provider.of<Timers>(context, listen: false);
  }

  static Timers watch(BuildContext context) {
    return Provider.of<Timers>(context, listen: true);
  }

  Future<void> remove(String exercise) async {
    _timers.remove(exercise);

    notifyListeners();

    if (userId case String userId) {
      return _service.setRestTimer(exerciseName: exercise, userId: userId, seconds: null);
    }
  }

  /// Keyed by exercise id.
  int? operator [](String exercise) => _timers[exercise];

  /// Whether the user has any rest-timer preference configured.
  bool get isNotEmpty => _timers.isNotEmpty;

  Future<void> setRestTimer(String exercise, int seconds) async {
    if (userId case String userId) {
      _timers[exercise] = seconds;
      notifyListeners();
      return _service.setRestTimer(exerciseName: exercise, userId: userId, seconds: seconds);
    }
  }

  Future<void> init() async {
    if (userId case String userId) {
      final stored = await _service.getTimers(userId);
      _timers.addAll(stored);
      notifyListeners();
    }
  }
}
