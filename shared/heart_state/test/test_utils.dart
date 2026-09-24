import 'package:flutter/foundation.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

// Increments and returns a function to attach as a listener for ChangeNotifier
int addCounterListener(ChangeNotifier notifier) {
  var count = 0;
  notifier.addListener(() => count++);
  // store count in a closure variable by returning getter? Simpler: caller captures reference.
  // Since Dart passes primitives by value, return the count initial value and rely on external closure not possible.
  // Provide a small wrapper type instead.
  return count; // Not used directly; prefer ListenerProbe below.
}

class ListenerProbe {
  int notifications = 0;
  void attach(ChangeNotifier notifier) {
    notifier.addListener(() => notifications++);
  }
}

// Convenience builders for real domain models used in tests
Exercise ex(String name, {Map<String, dynamic>? movement, bool archived = false}) {
  return Exercise.fromJson({
    // deterministic per name, so fixtures stay self-consistent across calls
    'id': 'id-${name.toLowerCase().replaceAll(' ', '-')}',
    'name': name,
    'category': 'Weighted Body Weight',
    'target': 'Chest',
    'asset': null,
    'thumbnail': null,
    'instructions': null,
    'archived': archived,
    'movement': ?movement,
  });
}

/// A movement annotation in wire shape. Defaults describe an unloaded, free,
/// bilateral, low-skill movement, so a test only states the attributes it is
/// actually about.
Map<String, dynamic> movement(
  List<String> groups, {
  String axialLoad = 'none',
  String stability = 'free',
  bool unilateral = false,
  String impact = 'none',
  String skill = 'low',
}) {
  return {
    'groups': groups,
    'axialLoad': axialLoad,
    'stability': stability,
    'unilateral': unilateral,
    'impact': impact,
    'skill': skill,
  };
}

Template tmpl({
  required String id,
  int order = 0,
  String? name,
  List<WorkoutExercise> exercises = const [],
  TemplateFolder? folder,
}) {
  final t = Template.empty(id: id, order: order, folder: folder);
  t.name = name;
  for (final we in exercises) {
    t.append(we);
  }
  return t;
}

TemplateFolder fldr({String id = 'f1', String name = 'Push', int order = 0}) {
  return TemplateFolder(id: id, name: name, order: order);
}

WorkoutExercise wEx(Exercise exercise, {int sets = 1}) {
  final starter = ExerciseSet(exercise);
  final we = WorkoutExercise(starter: starter);
  for (var i = 1; i < sets; i++) {
    we.add(starter.copy());
  }
  return we;
}

/// Records what was reported instead of verifying it.
///
/// Analytics assertions are about order and about absence, and a mock's
/// verified-call bookkeeping makes both awkward: `verify` throws rather than
/// returning nothing when a run logged nothing, and each call consumes the
/// calls it matched.
class ReportedAnalytics implements AnalyticsService {
  final events = <(String, Map<String, Object>)>[];
  final properties = <String, String?>{};

  Iterable<String> get names => events.map((each) => each.$1);

  /// The parameters of the one event called [name].
  Map<String, Object> parametersOf(String name) {
    return events.firstWhere((each) => each.$1 == name).$2;
  }

  /// The `arrival` of every sign-in event, in order.
  List<String> get arrivals {
    return events
        .where((each) => each.$1 == 'signup_completed' || each.$1 == 'login_completed')
        .map((each) => each.$2['arrival'] as String)
        .toList();
  }

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async {
    events.add((name, parameters));
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    properties[name] = value;
  }
}
