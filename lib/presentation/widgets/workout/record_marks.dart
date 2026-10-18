part of 'workout_detail.dart';

/// The records each set under [child] set, by set id: a past workout's page
/// puts its own here, and each set row shows its own as pills under it.
///
/// Only records that beat an earlier value are here ([recordMarks]): an
/// exercise's first session sets every record at once, and a pill on each of
/// its sets would bury the page — those stay counted on the Done page.
class RecordMarksScope extends InheritedWidget {
  final RecordMarks marks;

  /// On the first set with a record, in the workout's order: what the page's
  /// record count scrolls to.
  final GlobalKey first = GlobalKey();
  final String? firstSetId;

  new({super.key, required this.marks, required this.firstSetId, required super.child});

  static RecordMarksScope? _of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RecordMarksScope>();

  static List<RecordKind> of(BuildContext context, String setId) => _of(context)?.marks[setId] ?? const [];

  @override
  bool updateShouldNotify(RecordMarksScope old) => !identical(marks, old.marks);
}

/// A set's records as a row of small outlined pills under it — a trophy and a
/// short name each ("1RM", "VOL.", "WEIGHT"), wrapping. Each says its full
/// name to a screen reader and on a long press.
class RecordPills extends StatelessWidget {
  final List<RecordKind> kinds;

  const new({super.key, required this.kinds});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.labelSmall?.copyWith(color: colorScheme.tertiary, fontWeight: .w600, fontSize: 10);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final kind in kinds)
          Tooltip(
            message: recordKindLabel(context, kind),
            excludeFromSemantics: true,
            child: Semantics(
              label: L.of(context).recordSetBadge(recordKindLabel(context, kind)),
              excludeSemantics: true,
              child: DecoratedBox(
                key: WorkoutDetailKeys.recordPill(kind.key),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.tertiary),
                  borderRadius: const .all(.circular(10)),
                ),
                child: Padding(
                  padding: const .symmetric(horizontal: 6, vertical: 1),
                  child: Row(
                    mainAxisSize: .min,
                    spacing: 2,
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 11, color: colorScheme.tertiary),
                      Text(recordKindShort(context, kind), style: style),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "3 PRs", at the top of a past workout's page: how many records it set,
/// and a tap that scrolls to the first. Absent where it set none.
class RecordCountRow extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = RecordMarksScope._of(context);
    final count = scope?.marks.values.fold(0, (sum, kinds) => sum + kinds.length) ?? 0;
    if (scope == null || count == 0) return const SizedBox.shrink();
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Padding(
      padding: const .fromLTRB(8, 8, 8, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: WorkoutDetailKeys.recordCount,
          onPressed: () => switch (scope.first.currentContext) {
            final BuildContext first => Scrollable.ensureVisible(
              first,
              alignment: .3,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            ),
            null => null,
          },
          icon: Icon(Icons.emoji_events_rounded, size: 18, color: colorScheme.tertiary),
          label: Text(
            L.of(context).workoutPRs(count),
            style: textTheme.labelLarge?.copyWith(color: colorScheme.tertiary),
          ),
        ),
      ),
    );
  }
}
