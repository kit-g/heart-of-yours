part of 'exercises.dart';

enum _ExerciseSection {
  about,
  history,
  charts,
  records,
}

extension on Exercise {
  Iterable<_ExerciseSection> get sections {
    return _ExerciseSection.values.where((one) => hasInfo ? true : one != .about);
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

/// Remembers the last-viewed tab so switching exercises — e.g. in the iPad
/// master-detail — keeps you on the same one. Session-scoped, not persisted.
_ExerciseSection? _rememberedSection;

/// Which tab a detail page opens on: an explicit [tab] name (from a shared deep
/// link) wins, then the remembered tab, then the exercise's first available tab.
_ExerciseSection _initialSection(Exercise exercise, String? tab) {
  final sections = exercise.sections.toList();
  final named = _ExerciseSection.values.where((each) => each.name == tab);
  final requested = named.isNotEmpty ? named.first : _rememberedSection;
  return requested != null && sections.contains(requested) ? requested : sections.first;
}

List<Widget> _pages(
  Exercise exercise, {
  required final Future<void> Function(String) onTapWorkout,
  final void Function(ExerciseFilter)? onFilter,
  final void Function(Exercise)? onTapAlternative,
}) {
  return exercise.sections.map((section) {
    return _Page(
      section: section,
      exercise: exercise,
      onTapWorkout: onTapWorkout,
      onFilter: onFilter,
      onTapAlternative: onTapAlternative,
    );
  }).toList();
}

class _Page extends StatelessWidget {
  final _ExerciseSection section;
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;
  final void Function(ExerciseFilter)? onFilter;
  final void Function(Exercise)? onTapAlternative;

  const _Page({
    required this.section,
    required this.exercise,
    required this.onTapWorkout,
    this.onFilter,
    this.onTapAlternative,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16, top: 16),
      child: switch (section) {
        .about => _About(
          exercise: exercise,
          onFilter: onFilter,
          onTapAlternative: onTapAlternative,
        ),
        .charts => _Charts(exercise: exercise),
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

/// finds "beautiful" timestamps
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

Future<void> _onExerciseOptions(
  BuildContext context, {
  required VoidCallback onShowArchived,
  bool hasArchived = false,
}) async {
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
      if (hasArchived)
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
