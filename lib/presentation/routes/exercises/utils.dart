part of 'exercises.dart';

enum _ExerciseSection {
  about,
  history,
  charts,
  records;
}

extension on Exercise {
  Iterable<_ExerciseSection> get sections {
    return _ExerciseSection.values.where((one) => hasInfo ? true : one != _ExerciseSection.about);
  }
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
  return exercise.sections.map((section) {
    return _Page(section: section, exercise: exercise);
  }).toList();
}

class _Page extends StatelessWidget {
  final _ExerciseSection section;
  final Exercise exercise;

  const _Page({
    required this.section,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16, top: 16),
      child: switch (section) {
        _ExerciseSection.about => _About(exercise: exercise),
        _ExerciseSection.history => _History(exercise: exercise),
        _ExerciseSection.charts => _Charts(exercise: exercise),
        _ExerciseSection.records => _Records(exercise: exercise),
      },
    );
  }
}
