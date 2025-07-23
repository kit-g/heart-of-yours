import 'package:heart_models/heart_models.dart';

Exercise exercise({
  String name = 'Push Up',
  String target = 'Chest',
}) {
  return Exercise.fromJson({
    'name': name,
    'category': 'Weighted Body Weight',
    'target': target,
    'asset': 'https://dev.media.heart-of.me/exercises/$name/asset.gif',
    'assetWidth': 1080,
    'assetHeight': 1080,
    'thumbnail': 'https://dev.media.heart-of.me/exercises/$name/thumbnail.jpg',
    'thumbnailWidth': 200,
    'thumbnailHeight': 200,
    'instructions': null,
    'userId': null,
  });
}

ExerciseAct exerciseAct({
  String workoutId = '2025-04-06T18:49:51_445393Z',
  String? workoutName = 'Morning Push',
  DateTime? start,
  Exercise? ex,
  List<Map<String, dynamic>>? sets,
}) {
  ex ??= exercise();

  final rows = sets ??
      [
        {
          'workoutId': workoutId,
          'exerciseId': '2025-04-06T18:48:51_445393Z',
          'id': '2025-04-06T18:48:51_445393Z',
          'weight': 10,
          'reps': 12,
          'completed': 1,
        },
        {
          'workoutId': workoutId,
          'exerciseId': '2025-04-06T18:48:51_445393Z',
          'id': '2025-04-06T19:48:51_445393Z',
          'weight': 10,
          'reps': 10,
          'completed': 0,
        },
      ];

  return ExerciseAct.fromRows(ex, rows);
}

Workout workout({
  List<WorkoutExercise> exercises = const [],
  bool finished = false,
  String? name,
}) {
  final w = Workout(name: name ?? 'Morning');

  for (var each in exercises) {
    w.append(each);
  }

  if (finished) {
    w.finish(DateTime.now());
  }

  return w;
}

WorkoutExercise wExercise({
  Exercise? ex,
  List<ExerciseSet> sets = const [],
}) {
  final we = WorkoutExercise(
    starter: ExerciseSet(ex ?? exercise(name: 'Push Up')),
  );

  for (var each in sets) {
    we.add(each);
  }
  return we;
}

ExerciseSet set({Exercise? ex, double? weight, int? reps, int? duration, double? distance, bool? isCompleted}) {
  return ExerciseSet(
    ex ?? exercise(),
    weight: weight ?? 50,
    reps: reps ?? 10,
    duration: duration ?? 60,
    distance: distance ?? 1,
  )..isCompleted = isCompleted ?? true;
}

Template template({String? id, Workout? w, int order = 0}) {
  return Template.fromWorkout(id ?? '0', w ?? workout(), order);
}

extension CaseUtils on String {
  String toSnake() {
    return replaceAllMapped(RegExp(r'(.)([A-Z])'), (Match m) => '${m[1]}_${m[2]}').toLowerCase();
  }
}
