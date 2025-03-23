part of 'exercises.dart';

enum _ExerciseSection {
  about,
  history,
  charts,
  records;
}

String _copy(BuildContext context, _ExerciseSection section) {
  return switch (section) {
    _ExerciseSection.about => L.of(context).about,
    _ExerciseSection.history => L.of(context).history,
    _ExerciseSection.charts => L.of(context).charts,
    _ExerciseSection.records => L.of(context).records,
  };
}

List<Widget> _pages(Exercise exercise) {
  return _ExerciseSection.values.map((section) {
    return switch (section) {
      _ExerciseSection.about => _About(exercise: exercise),
      _ExerciseSection.history => _History(exercise: exercise),
      _ExerciseSection.charts => _Charts(exercise: exercise),
      _ExerciseSection.records => _Records(exercise: exercise),
    };
  }).toList();
}
