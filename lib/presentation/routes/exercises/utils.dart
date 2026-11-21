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
  required Future<void> Function(String) onTapWorkout,
  void Function(ExerciseFilter)? onFilter,
  void Function(Exercise)? onTapAlternative,
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

  const new({
    required this.section,
    required this.exercise,
    required this.onTapWorkout,
    this.onFilter,
    this.onTapAlternative,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: switch (section) {
        // About insets its own children: the "also try" row has to scroll clear
        // to the screen edge, which a padded ancestor would cut short.
        .about => const .only(top: 16),
        _ => const .only(left: 16, right: 16, top: 16),
      },
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
          onTapWorkout: onTapWorkout,
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

/// One width for both ⋯ menus here, so a long label wraps inside the menu
/// rather than pushing it off the screen's edge; their right edge hangs from
/// the button's.
const _optionsMenuWidth = 240.0;

/// What an exercise page's ⋯ offers.
enum _ExerciseOption { edit, moveHistory, archive, unarchive }

/// An exercise page's ⋯, hanging off [button] (#710).
///
/// A library exercise has nothing here but the history move: it is not the
/// user's to edit or archive.
///
/// The menu closes itself on a pick, and what follows acts on the answer: there
/// is no sheet left to pop, and a pop here would take the page instead.
Future<void> _onExerciseMenu(
  BuildContext button,
  Exercise exercise, {
  void Function(Exercise target)? onHistoryMoved,
}) async {
  final l = L.of(button);
  final options = <_ExerciseOption>[
    if (exercise.isMine) .edit,
    if (_canMoveHistory(button, exercise, onMoved: onHistoryMoved)) .moveHistory,
    if (exercise.isMine) exercise.isArchived ? .unarchive : .archive,
  ];
  final picked = await showMenu<_ExerciseOption>(
    context: button,
    position: menuEndingUnder(button, width: _optionsMenuWidth),
    constraints: const .tightFor(width: _optionsMenuWidth),
    items: [
      for (final option in options)
        _optionItem(
          option,
          icon: switch (option) {
            .edit => Icons.edit_rounded,
            .moveHistory => Icons.call_merge_rounded,
            .archive => Icons.archive_rounded,
            .unarchive => Icons.restore_outlined,
          },
          title: switch (option) {
            .edit => l.edit,
            .moveHistory => l.moveHistory,
            .archive => l.archive,
            .unarchive => l.unarchive,
          },
        ),
    ],
  );
  if (!button.mounted) return;
  switch (picked) {
    case .edit:
      showNewExerciseDialog(button, editable: exercise);
    case .moveHistory:
      if (onHistoryMoved case final onMoved?) _onMoveHistory(button, exercise, onMoved: onMoved);
    case .archive:
      _onArchive(button, exercise);
    case .unarchive:
      _onUnarchive(button, exercise);
    case null:
      break;
  }
}

/// A choice in one of the ⋯ menus: its icon where a checked choice has its
/// check, so the two kinds line up.
PopupMenuItem<T> _optionItem<T>(T value, {required IconData icon, required String title}) {
  return PopupMenuItem<T>(
    value: value,
    child: ListTile(
      contentPadding: .zero,
      leading: Icon(icon),
      title: Text(title),
    ),
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
      color: colorScheme.error,
    ),
    actions: [
      Column(
        spacing: 8,
        children: [
          PrimaryButton.wide(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Center(
              child: Text(cancel),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
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

/// Out of the dialog and off the page, which has nothing left to show once the
/// exercise is put away.
Future<void> _onConfirmArchive(BuildContext context, Exercise exercise) async {
  // read while the page is still here: the pops take its context with it
  final exercises = Exercises.of(context);
  Navigator.of(context, rootNavigator: true).pop();
  Navigator.of(context).pop();
  await exercises.archive(exercise);
}

/// What the Exercises tab's ⋯ answers with.
sealed class _LibraryOption {
  const new();
}

final class _NewExercise extends _LibraryOption {
  const new();
}

final class _ShowArchived extends _LibraryOption {
  const new();
}

final class _GroupBy extends _LibraryOption {
  final PickerGrouping grouping;

  const new(this.grouping);
}

/// The Exercises tab's ⋯, hanging off [button]: a new exercise, how the
/// library and every picker group (#620), and the archive when it holds
/// anything. The groupings are in the menu itself, the one in force checked,
/// so the choice is made where the button is (#710).
Future<void> _onExerciseOptions(
  BuildContext button, {
  required VoidCallback onShowArchived,
  bool hasArchived = false,
}) async {
  final l = L.of(button);
  final grouping = Preferences.of(button).pickerGrouping;
  final picked = await showMenu<_LibraryOption>(
    context: button,
    position: menuEndingUnder(button, width: _optionsMenuWidth),
    constraints: const .tightFor(width: _optionsMenuWidth),
    items: [
      _optionItem(const _NewExercise(), icon: Icons.add_circle_outline_rounded, title: l.newExercise),
      const PopupMenuDivider(),
      _MenuHeading(l.settingsPickerGrouping),
      for (final each in PickerGrouping.values)
        CheckedPopupMenuItem<_LibraryOption>(
          value: _GroupBy(each),
          checked: each == grouping,
          child: Text(each.label(l)),
        ),
      if (hasArchived) ...[
        const PopupMenuDivider(),
        _optionItem(const _ShowArchived(), icon: Icons.archive_outlined, title: l.showArchived),
      ],
    ],
  );
  if (!button.mounted) return;
  switch (picked) {
    case _NewExercise():
      showNewExerciseDialog(button);
    case _ShowArchived():
      onShowArchived();
    // a change from what the menu showed checked, not from what is stored now:
    // tapping the checked one keeps what the user saw, and must not overwrite
    // a newer grouping sync adopted from another device while the menu was up
    case _GroupBy(grouping: final chosen) when chosen != grouping:
      Preferences.of(button).setPickerGrouping(chosen);
    case _GroupBy() || null:
      break;
  }
}

/// A section's title inside a menu: not a choice, so not a [PopupMenuItem],
/// which would be announced as a dimmed button.
class _MenuHeading<T> extends PopupMenuEntry<T> {
  final String title;

  const new(this.title);

  @override
  double get height => 32;

  @override
  bool represents(T? value) => false;

  @override
  State<_MenuHeading<T>> createState() => _MenuHeadingState<T>();
}

class _MenuHeadingState<T> extends State<_MenuHeading<T>> {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const .fromLTRB(12, 8, 12, 4),
        child: Text(
          widget.title,
          style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Back on the page beneath once the exercise is out of the archive; and past
/// the archive too, to the very top, when nothing is left in it.
Future<void> _onUnarchive(BuildContext context, Exercise exercise) async {
  final exercises = Exercises.of(context);
  final navigator = Navigator.of(context);
  await exercises.unarchive(exercise);
  navigator.pop();
  if (exercises.archived.isEmpty) navigator.pop();
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
