import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Timers with ChangeNotifier implements SignOutStateSentry {
  final _timers = <String, int>{};

  @override
  void onSignOut() {
    _timers.clear();
  }

  static Timers of(BuildContext context) {
    return Provider.of<Timers>(context, listen: false);
  }

  static Timers watch(BuildContext context) {
    return Provider.of<Timers>(context, listen: true);
  }

  void add(String exercise, int duration) {
    _timers[exercise] = duration;
    notifyListeners();
  }

  void remove(String exercise) {
    _timers.remove(exercise);
    notifyListeners();
  }

  int? operator [](String exercise) => _timers[exercise];

  void operator []=(String exercise, int duration) {
    _timers[exercise] = duration;
    notifyListeners();
  }
}
