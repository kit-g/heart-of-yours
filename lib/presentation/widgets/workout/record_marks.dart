part of 'workout_detail.dart';

/// The records each set under [child] set (#F20), by set id: a past
/// workout's page puts its own here, and each set row marks its own.
class RecordMarksScope extends InheritedWidget {
  final RecordMarks marks;

  const new({super.key, required this.marks, required super.child});

  static List<RecordKind> of(BuildContext context, String setId) {
    return context.dependOnInheritedWidgetOfExactType<RecordMarksScope>()?.marks[setId] ?? const [];
  }

  @override
  bool updateShouldNotify(RecordMarksScope old) => !identical(marks, old.marks);
}

/// A set's records, small beside its number: a trophy, and how many when
/// more than one. Says which records in its tooltip and to a screen reader.
class _RecordMark extends StatelessWidget {
  final List<RecordKind> kinds;

  const new({required this.kinds});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final named = L.of(context).recordSetBadge(kinds.map((kind) => recordKindLabel(context, kind)).join(', '));
    return Tooltip(
      message: named,
      excludeFromSemantics: true,
      child: Semantics(
        label: named,
        child: DecoratedBox(
          key: WorkoutDetailKeys.recordMark,
          decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: const .all(.circular(8))),
          child: Padding(
            padding: const .symmetric(horizontal: 4, vertical: 1),
            child: Row(
              mainAxisSize: .min,
              spacing: 1,
              children: [
                Icon(Icons.emoji_events_rounded, size: 11, color: colorScheme.onTertiaryContainer),
                if (kinds.length > 1)
                  Text(
                    '${kinds.length}',
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.onTertiaryContainer, fontSize: 9),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
