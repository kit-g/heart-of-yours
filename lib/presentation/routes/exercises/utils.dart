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

List<Widget> _pages(
  Exercise exercise, {
  required final Future<void> Function(String) onTapWorkout,
}) {
  return exercise.sections.map((section) {
    return _Page(
      section: section,
      exercise: exercise,
      onTapWorkout: onTapWorkout,
    );
  }).toList();
}

class _Page extends StatelessWidget {
  final _ExerciseSection section;
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;

  const _Page({
    required this.section,
    required this.exercise,
    required this.onTapWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16, top: 16),
      child: switch (section) {
        _ExerciseSection.about => _About(exercise: exercise),
        _ExerciseSection.charts => _Charts(
            exercise: exercise,
            weightHistoryLookup: Exercises.of(context).getWeightHistory,
            repsHistoryLookup: Exercises.of(context).getRepsHistory,
            distanceHistoryLookup: Exercises.of(context).getDistanceHistory,
            durationHistoryLookup: Exercises.of(context).getDurationHistory,
          ),
        _ExerciseSection.records => _Records(
            exercise: exercise,
            recordsLookup: Exercises.of(context).getExerciseRecords,
          ),
        _ExerciseSection.history => _History(
            exercise: exercise,
            historyLookup: (exercise, {pageSize, anchor}) {
              return Exercises.of(context).getExerciseHistory(exercise, pageSize: pageSize, anchor: anchor);
            },
            onTapWorkout: onTapWorkout,
          ),
      },
    );
  }
}

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

extension on Duration {
  String formatted() {
    final minutes = _pad(inMinutes.remainder(60));
    final seconds = _pad(inSeconds.remainder(60));
    return switch (inHours) {
      > 0 => '${_pad(inHours)}:$minutes:$seconds',
      _ => '$minutes:$seconds',
    };
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

String _double(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  return rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toStringAsFixed(1);
}

/// finds "beautiful timestamps
/// for chart axes
/// e.g., 1:30 or 30:00 are beautiful
/// and 1:15 and 33:30 are ugly
String? _beautify(double y) {
  int seconds = y.round();

  final roundTo = switch (y.round()) {
    < 60 => 10, // to nearest 10s
    < 600 => 30, // to nearest 30s
    < 3600 => 300, // to nearest 5min
    _ => 900, // to nearest 5min
  };

  // apply rounding
  int rounded = (seconds / roundTo).round() * roundTo;

  // filter out "ugly" labels
  if (rounded % 60 != 0 && rounded >= 600) {
    return null; // drop values that aren’t full minutes after 10 min
  }
  return Duration(seconds: rounded).formatted();
}
