import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Stats with ChangeNotifier implements SignOutStateSentry {
  final _db = FirebaseFirestore.instance;

  final void Function(dynamic error, {dynamic stacktrace})? onError;

  Stats({required this.onError});

  String? userId;

  WorkoutAggregation workouts = WorkoutAggregation.empty();

  @override
  void onSignOut() {
    workouts = WorkoutAggregation.empty();
  }

  static Stats of(BuildContext context) {
    return Provider.of<Stats>(context, listen: false);
  }

  static Stats watch(BuildContext context) {
    return Provider.of<Stats>(context, listen: true);
  }

  Future<void> init() async {
    if (userId case String id) {
      final user = await _db.collection('aggregations').doc(id).get();
      final aggregation = (user.data() ?? {})['workouts'] ?? <String, dynamic>{};
      workouts = WorkoutAggregation.fromJson(aggregation);
      notifyListeners();
    }
  }
}
