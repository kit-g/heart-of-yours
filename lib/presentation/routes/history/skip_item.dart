part of 'history.dart';

/// History's rows: each month's header, then its workouts and the days set
/// aside with "Not today" (#312), newest first. While older workouts are still
/// to be paged down, a skip older than the oldest one shown waits for them, so
/// it never sits above a gap.
List<Object> _historyRows(Map<String, List<Workout>> byMonth, Iterable<TrainingSkip> skips, {required bool partial}) {
  final oldest = byMonth.values.lastOrNull?.lastOrNull?.start;
  final months = SplayTreeMap<String, List<Object>>((a, b) => b.compareTo(a))
    ..addAll({
      for (final MapEntry(:key, :value) in byMonth.entries) key: [...value],
    });

  for (final skip in [...skips]..sort((a, b) => b.at.compareTo(a.at))) {
    final at = skip.at.toLocal();
    if (partial && oldest != null && at.isBefore(oldest)) continue;
    final rows = months.putIfAbsent('${at.year}-${at.month.toString().padLeft(2, '0')}', () => []);
    final before = rows.indexWhere(
      (row) => switch (row) {
        Workout(:final start) => start.isBefore(at),
        TrainingSkip(at: final other) => other.toLocal().isBefore(at),
        _ => false,
      },
    );
    rows.insert(before == -1 ? rows.length : before, skip);
  }
  return [
    for (final MapEntry(key: month, value: rows) in months.entries) ...[month, ...rows],
  ];
}

/// A day set aside with "Not today" (#312): the session, its program and the
/// day, quieter than a workout's card. Tapped, it opens on a page of its own
/// (#391), with the way on to the program.
class _SkipItem extends StatelessWidget {
  final TrainingSkip skip;
  final void Function(TrainingSkip)? onTap;

  const new({required this.skip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final session = switch (skip.templateId) {
      final String id => Templates.watch(context).lookup(id)?.name,
      null => null,
    };
    final program = switch (skip.programId) {
      final String id => Programs.watch(context).lookup(id)?.name,
      null => null,
    };
    final day = DateFormat.MMMEd(copy.localeName).format(skip.at.toLocal());
    // the words say what it was once: under the session, or in its place
    final details = [if (session != null) copy.programNotToday, ?program, day].join(' · ');

    return Padding(
      padding: const .symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        key: AppKeys.historySkip(skip.id),
        dense: true,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outlineVariant),
          borderRadius: const .all(.circular(12)),
        ),
        leading: Icon(Icons.redo_rounded, color: colorScheme.outline),
        title: Text(
          session ?? copy.programNotToday,
          maxLines: 1,
          overflow: .ellipsis,
          style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        subtitle: Text(details, maxLines: 1, overflow: .ellipsis),
        onTap: switch ((onTap, skip.id)) {
          (final void Function(TrainingSkip) open, String _) => () => open(skip),
          _ => null,
        },
      ),
    );
  }
}
