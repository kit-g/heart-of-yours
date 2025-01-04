import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Exercises with ChangeNotifier, Iterable<Exercise> implements SignOutStateSentry {
  final bool isCached;
  final _db = FirebaseFirestore.instance;
  final _scrollController = ScrollController();

  Exercises({this.isCached = true});

  bool isInitialized = false;

  ScrollController get scrollController => _scrollController;

  final _exercises = <Exercise>[];

  @override
  void onSignOut() {
    _exercises.clear();
  }

  @override
  Iterator<Exercise> get iterator => _exercises.iterator;

  Exercise operator [](int index) => _exercises[index];

  static Exercises of(BuildContext context) {
    return Provider.of<Exercises>(context, listen: false);
  }

  static Exercises watch(BuildContext context) {
    return Provider.of<Exercises>(context, listen: true);
  }

  Future<void> init() async {
    final options = GetOptions(source: isCached ? Source.cache : Source.serverAndCache);
    final all = await _db //
        .collection('exercises')
        .withConverter<Exercise>(
          fromFirestore: _fromFirestore,
          toFirestore: (exercise, _) => exercise.toMap(),
        )
        .get(options);

    _exercises.addAll(all.docs.map(_snapshot));
    isInitialized = true;
    notifyListeners();
  }

  Iterable<Exercise> search(String query) {
    return _exercises.where((one) => one.contains(query));
  }
}

Exercise _snapshot(QueryDocumentSnapshot<Exercise> snapshot) => snapshot.data();

Exercise _fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? _) {
  return Exercise.fromJson(snapshot.data()!);
}
