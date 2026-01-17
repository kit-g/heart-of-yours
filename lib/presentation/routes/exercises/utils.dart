part of 'exercises.dart';

enum _ExerciseSection {
  about,
  history,
  charts,
  records,
}

extension on Exercise {
  Iterable<_ExerciseSection> get sections {
    return _ExerciseSection.values.where((one) => hasInfo ? true : one != _ExerciseSection.about);
  }
}

String _copy(BuildContext context, _ExerciseSection section) {
  return switch (section) {
    .about => L.of(context).about,
    .history => L.of(context).history,
    .charts => L.of(context).charts,
    .records => L.of(context).records,
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
        .about => _About(exercise: exercise),
        .charts => _Charts(
          exercise: exercise,
          weightHistoryLookup: Exercises.of(context).getWeightHistory,
          repsHistoryLookup: Exercises.of(context).getRepsHistory,
          distanceHistoryLookup: Exercises.of(context).getDistanceHistory,
          durationHistoryLookup: Exercises.of(context).getDurationHistory,
        ),
        .records => _Records(
          exercise: exercise,
          recordsLookup: Exercises.of(context).getExerciseRecords,
        ),
        .history => _History(
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

const _shape = RoundedRectangleBorder(borderRadius: .all(.circular(8)));

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

Future<void> _onExerciseMenu(BuildContext context, Exercise exercise) {
  final L(:archive, :unarchive, :edit) = L.of(context);
  return showBottomMenu(
    context,
    [
      if (exercise.isMine)
        BottomMenuAction(
          title: edit,
          onPressed: () => showNewExerciseDialog(context, editable: exercise),
          icon: const Icon(Icons.edit_rounded),
        ),
      if (exercise.isArchived)
        BottomMenuAction(
          title: unarchive,
          onPressed: () => _onUnarchive(context, exercise),
          icon: const Icon(Icons.restore_outlined),
        )
      else
        BottomMenuAction(
          title: archive,
          onPressed: () => _onArchive(context, exercise),
          icon: const Icon(Icons.archive_rounded),
        ),
    ],
  );
}

Future<void> _onArchive(BuildContext context, Exercise exercise) async {
  final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
  final L(:archiveConfirmTitle, :archiveConfirmBody, :archive, :cancel) = L.of(context);
  return showBrandedDialog(
    context,
    title: Text(
      archiveConfirmTitle(exercise.name),
      textAlign: .center,
    ),
    content: Text(
      archiveConfirmBody,
      textAlign: .center,
    ),
    icon: Icon(
      Icons.error_outline_rounded,
      color: colorScheme.onErrorContainer,
    ),
    actions: [
      Column(
        spacing: 8,
        children: [
          PrimaryButton.wide(
            backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
            child: Center(
              child: Text(cancel),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).pop();
            },
          ),
          PrimaryButton.wide(
            backgroundColor: colorScheme.errorContainer,
            child: Center(
              child: Text(
                archive,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
            onPressed: () {
              _onConfirmArchive(context, exercise);
            },
          ),
        ],
      ),
    ],
  );
}

Future<void> _onConfirmArchive(BuildContext context, Exercise exercise) async {
  // close the dialog
  Navigator.of(context, rootNavigator: true).pop();
  Navigator.of(context)
    ..pop()
    ..pop();
  // state
  await Exercises.of(context).archive(exercise);
}

Future<void> _onExerciseOptions(BuildContext context, {required VoidCallback onShowArchived}) async {
  return showBottomMenu(
    context,
    [
      BottomMenuAction(
        title: L.of(context).newExercise,
        icon: const Icon(Icons.add_circle_outline_rounded),
        onPressed: () {
          Navigator.of(context).pop();
          showNewExerciseDialog(context);
        },
      ),
      BottomMenuAction(
        title: L.of(context).showArchived,
        icon: const Icon(Icons.archive_outlined),
        onPressed: () {
          Navigator.of(context).pop();
          onShowArchived();
        },
      ),
    ],
  );
}

Future<void> _onUnarchive(BuildContext context, Exercise exercise) async {
  final exercises = Exercises.of(context);
  final navigator = Navigator.of(context);
  // state
  await exercises.unarchive(exercise);

  // pop
  if (exercises.archived.isEmpty) {
    // go to the very top if nothing is left in the archive
    navigator
      // out of dialog
      ..pop()
      // out of detail page
      ..pop()
      // out of archive
      ..pop();
  } else {
    navigator
      ..pop()
      ..pop();
  }
}

extension on Exercise {
  Widget archivedAppBarTitle(BuildContext context) {
    return switch (isArchived) {
      true => RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextSpan(
              text: '  ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            WidgetSpan(
              child: Tooltip(
                message: L.of(context).exerciseArchived,
                child: const Icon(Icons.archive_outlined),
              ),
            ),
          ],
        ),
      ),
      false => Text(name),
    };
  }
}
