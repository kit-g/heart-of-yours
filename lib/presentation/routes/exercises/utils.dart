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

/// The width both ⋯ menus here take where there is room for it, so a long
/// label wraps inside the menu rather than pushing it off the screen's edge.
const _optionsMenuWidth = 240.0;

/// Shows [items] in a menu hanging off [button], its right edge on the
/// button's: [_optionsMenuWidth] wide where there is room, narrower where
/// there is not (see [menuEndingUnder]).
///
/// [showMenu] rather than a [PopupMenuButton]: the button's own menu starts at
/// the button's left edge wherever there is more room to its right than its
/// left, which, for the trailing button of a narrow master pane, is out over
/// the detail pane.
Future<T?> _showOptions<T>(BuildContext button, List<PopupMenuEntry<T>> items) {
  final (:position, :constraints) = menuEndingUnder(button, width: _optionsMenuWidth);
  return showMenu<T>(context: button, position: position, constraints: constraints, items: items);
}

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
  VoidCallback? onArchived,
  VoidCallback? onUnarchived,
}) async {
  final l = L.of(button);
  final options = <_ExerciseOption>[
    if (exercise.isMine) .edit,
    if (_canMoveHistory(button, exercise, onMoved: onHistoryMoved)) .moveHistory,
    if (exercise.isMine) exercise.isArchived ? .unarchive : .archive,
  ];
  // a backstop: the button watches what these read, and is not there when
  // they come to nothing
  if (options.isEmpty) return;
  final picked = await _showOptions<_ExerciseOption>(
    button,
    options.map((option) {
      final (icon, title) = _exerciseOptionLook(l, option);
      return _optionItem(option, icon: icon, title: title);
    }).toList(),
  );
  if (!button.mounted) return;
  switch (picked) {
    case .edit:
      showNewExerciseDialog(button, editable: exercise);
    case .moveHistory:
      if (onHistoryMoved case final onMoved?) _onMoveHistory(button, exercise, onMoved: onMoved);
    case .archive:
      unawaited(_onArchive(button, exercise, onArchived: onArchived));
    case .unarchive:
      unawaited(_onUnarchive(button, exercise, onUnarchived: onUnarchived));
    case null:
      break;
  }
}

(IconData, String) _exerciseOptionLook(L l, _ExerciseOption option) {
  return switch (option) {
    .edit => (Icons.edit_rounded, l.edit),
    .moveHistory => (Icons.call_merge_rounded, l.moveHistory),
    .archive => (Icons.archive_rounded, l.archive),
    .unarchive => (Icons.restore_outlined, l.unarchive),
  };
}

/// A choice in one of the ⋯ menus: its icon where a checked choice has its
/// check, so the two kinds line up.
PopupMenuItem<T> _optionItem<T>(T value, {required IconData icon, required String title}) {
  return PopupMenuItem<T>(
    value: value,
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
    ),
  );
}

/// Asks before archiving; confirmed, leaves the page, then archives.
///
/// Everything the answer needs is read now, from the page: the dialog sits on
/// the root navigator and can outlive the page, as when a link the user
/// follows meanwhile `go`es elsewhere and replaces what was under it.
Future<void> _onArchive(BuildContext context, Exercise exercise, {VoidCallback? onArchived}) {
  final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
  final copy = L.of(context);
  final L(:archiveConfirmTitle, :archiveConfirmBody, :archive, :cancel) = copy;
  final root = Navigator.of(context, rootNavigator: true);
  final leave = _leaving(context, onArchived);
  final putAway = _putAway(
    context,
    (exercises) => exercises.archive(exercise),
    copy.exerciseArchiveFailed(exercise.name),
  );
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
            onPressed: () => root.pop(),
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
              root.pop();
              leave();
              unawaited(putAway());
            },
          ),
        ],
      ),
    ],
  );
}

/// Leaves the page, then takes the exercise out of the archive.
Future<void> _onUnarchive(BuildContext context, Exercise exercise, {VoidCallback? onUnarchived}) {
  final putAway = _putAway(
    context,
    (exercises) => exercises.unarchive(exercise),
    L.of(context).exerciseUnarchiveFailed(exercise.name),
  );
  _leaving(context, onUnarchived)();
  return putAway();
}

/// How the page leaves once its exercise is archived or unarchived, read
/// while it is here: [onLeave], where the route says, or else back to what
/// is under the page, if anything is. Before the change, so the leaving is
/// not counted against whatever the user opens or goes back to while the
/// account answers; and not at all once the page is gone, as a link the
/// user followed meanwhile already decided where they are.
VoidCallback _leaving(BuildContext context, VoidCallback? onLeave) {
  final page = ModalRoute.of(context);
  return () {
    if (!context.mounted) return;
    switch (onLeave) {
      case final VoidCallback leave:
        leave();
      case null:
        popIfCurrent(page);
    }
  };
}

/// [change] made to the exercises, a failure said with [failure] in a snack
/// and reported. Read from [context] now, while the page is here: the change
/// runs once the user has left it, so the snack shows where they went.
Future<void> Function() _putAway(
  BuildContext context,
  Future<void> Function(Exercises) change,
  String failure,
) {
  final exercises = Exercises.of(context);
  final messenger = ScaffoldMessenger.of(context);
  return () async {
    try {
      await change(exercises);
    } catch (e, s) {
      reportToSentry(e, stacktrace: s);
      messenger.snack(failure);
    }
  };
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
  final shown = ShownPickerGrouping.of(Preferences.of(button));
  final picked = await _showOptions<_LibraryOption>(button, [
    _optionItem(const _NewExercise(), icon: Icons.add_circle_outline_rounded, title: l.newExercise),
    const PopupMenuDivider(),
    _MenuHeading(l.settingsPickerGrouping),
    ...shown.items<_LibraryOption>(l, _GroupBy.new),
    if (hasArchived) ...[
      const PopupMenuDivider(),
      _optionItem(const _ShowArchived(), icon: Icons.archive_outlined, title: l.showArchived),
    ],
  ]);
  if (!button.mounted) return;
  switch (picked) {
    case _NewExercise():
      showNewExerciseDialog(button);
    case _ShowArchived():
      onShowArchived();
    case _GroupBy(:final grouping):
      shown.apply(Preferences.of(button), grouping);
    case null:
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
