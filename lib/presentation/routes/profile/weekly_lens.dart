part of 'profile.dart';

/// What the weekly sets card groups by (#341): the two keys over the same sets
/// (`docs/2026-10-11.pattern-lens.md`, rule 1).
enum _LensKey { patterns, muscles }

/// The weeks the card reads: the eight of the workouts-per-week chart above.
const _lensWeeks = 8;

/// The lines shown before "Show all": the keys trained most this week.
const _lensLines = 6;

/// The width of a line's eight bars.
const _lensBarsWidth = 96.0;

/// One key's line: what it is called, and its weeks oldest first. Counts stay
/// fractional here and become whole numbers only when they are drawn (rule 8).
typedef _LensLine = ({String label, List<LensCount> weeks});

/// The weekly sets card's slot on the profile (#341): baseline, so there is no
/// offer and no switch — absent only while there is nothing logged to count.
class const _WeeklyLensSection({
  required final WorkoutAggregation workouts,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: switch (workouts.isEmpty) {
        true => const SizedBox.shrink(),
        false => Padding(
          padding: const .only(left: 16, right: 16, bottom: 8),
          child: _WeeklyLensCard(workouts: workouts),
        ),
      },
    );
  }
}

/// Sets and sessions per week, by movement pattern or by muscle group: what a
/// week trained, across exercises. It does not matter that you bench six sets
/// a week; it matters whether you press, and how often.
class _WeeklyLensCard extends StatefulWidget {
  /// Only its identity is read: [Stats] replaces it whenever a workout is
  /// finished or deleted, which is when the counts go stale.
  final WorkoutAggregation workouts;

  const new({required this.workouts});

  @override
  State<_WeeklyLensCard> createState() => _WeeklyLensCardState();
}

class _WeeklyLensCardState extends State<_WeeklyLensCard> {
  final _key = ValueNotifier(_LensKey.patterns);
  final _unfolded = ValueNotifier(false);
  late final _choice = Listenable.merge([_key, _unfolded]);

  /// One read serves both keys, so switching between them counts in memory.
  /// Kept until the history changes.
  Future<List<LensSets>>? _rows;

  @override
  void didUpdateWidget(covariant _WeeklyLensCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.workouts, widget.workouts)) _rows = null;
  }

  @override
  void dispose() {
    _key.dispose();
    _unfolded.dispose();
    super.dispose();
  }

  Future<List<LensSets>> _read(DateTime now, int firstWeekday) {
    return _rows ??= Stats.of(context).getLensSets(
      lastWeeksOf(_lensWeeks, now: now, firstWeekday: firstWeekday).first,
      DateTime(now.year, now.month, now.day + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    final now = DateTime.now();
    final firstWeekday = firstWeekdayOf(context);

    return Column(
      key: AppKeys.lensCard,
      crossAxisAlignment: .stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _tileHeaderHeight),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(l.lensTitle, style: textTheme.titleLarge, maxLines: 2, overflow: .ellipsis),
              ),
              ValueListenableBuilder<_LensKey>(
                valueListenable: _key,
                builder: (_, key, _) {
                  return SettingSwitcher<_LensKey>(
                    value: key,
                    onValueChanged: (value) => _key.value = value ?? key,
                    children: {
                      .patterns: Text(l.lensPatterns),
                      .muscles: Text(l.lensMuscles),
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<LensSets>>(
          future: _read(now, firstWeekday),
          builder: (context, snapshot) {
            return switch (snapshot.data) {
              List<LensSets> rows => ListenableBuilder(
                listenable: _choice,
                builder: (context, _) {
                  final key = _key.value;
                  final lines = switch (key) {
                    .patterns => _lines(
                      countByWeek(rows, weeks: _lensWeeks, now: now, keysOf: patternsOf, firstWeekday: firstWeekday),
                      (pattern) => patternLabel(pattern, l),
                    ),
                    .muscles => _lines(
                      countByWeek(
                        rows,
                        weeks: _lensWeeks,
                        now: now,
                        keysOf: muscleGroupsOf,
                        firstWeekday: firstWeekday,
                      ),
                      (group) => group.label(l),
                    ),
                  };
                  return _WeeklyLensBody(
                    lines: lines,
                    unfolded: _unfolded.value,
                    onUnfold: (unfolded) => _unfolded.value = unfolded,
                    empty: switch ((key, rows.isEmpty)) {
                      (.patterns, false) => l.lensNoPatternsYet,
                      _ => l.lensNothingYet,
                    },
                  );
                },
              ),
              null => const SizedBox(
                height: _tileHeaderHeight * 2,
                child: Center(child: CircularProgressIndicator()),
              ),
            };
          },
        ),
      ],
    );
  }

  /// [counts] as lines, one per key with at least one whole set in the
  /// window: the most trained this week first, then over the whole window.
  List<_LensLine> _lines<K>(Map<DateTime, Map<K, LensCount>> counts, String Function(K key) label) {
    final keys = {for (final week in counts.values) ...week.keys};
    const none = (sets: .0, sessions: 0);
    double total(_LensLine line) => line.weeks.fold(.0, (sum, week) => sum + week.sets);
    return [
      for (final key in keys) (label: label(key), weeks: [for (final week in counts.values) week[key] ?? none]),
    ].where((line) => total(line).round() > 0).toList()..sort(
      (a, b) => switch (b.weeks.last.sets.compareTo(a.weeks.last.sets)) {
        0 => switch (total(b).compareTo(total(a))) {
          0 => a.label.compareTo(b.label),
          final order => order,
        },
        final order => order,
      },
    );
  }
}

/// The card's lines, in as many columns as the width the profile hands it
/// takes at a chart card's width each: one on a phone, two or three across a
/// tablet, so a line's label and its bars never drift a screen apart.
class const _WeeklyLensBody({
  required final List<_LensLine> lines,
  required final bool unfolded,
  required final ValueChanged<bool> onUnfold,
  required final String empty,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, colorScheme: ColorScheme(:onSurfaceVariant)) = Theme.of(context);

    if (lines.isEmpty) {
      return Padding(
        padding: const .symmetric(vertical: 8),
        child: Text(empty, style: textTheme.bodyMedium?.copyWith(color: onSurfaceVariant)),
      );
    }

    final shown = switch (unfolded) {
      true => lines,
      false => lines.take(_lensLines).toList(),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final columns = columnsFor(constraints.maxWidth, maxExtent: _maxChartCardWidth);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: .start,
          children: [
            Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                for (final line in shown)
                  SizedBox(
                    width: width,
                    child: _LensLineTile(line: line),
                  ),
              ],
            ),
            if (lines.length > _lensLines)
              TextButton(
                key: AppKeys.lensShowAll,
                onPressed: () => onUnfold(!unfolded),
                child: Text(switch (unfolded) {
                  true => l.lensShowFewer,
                  false => l.lensShowAll(lines.length),
                }),
              ),
          ],
        );
      },
    );
  }
}

/// One key: its name and this week in words, and its weeks as bars, oldest
/// first. The bars carry the numbers only by height, so a screen reader hears
/// them as a list instead.
class const _LensLineTile({
  required final _LensLine line,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, colorScheme: ColorScheme(:primary, :onSurfaceVariant)) = Theme.of(context);
    final weeks = [for (final week in line.weeks) week.sets.round()];
    final now = line.weeks.last;
    final summary = switch (now.sets.round()) {
      0 => l.lensNoneThisWeek,
      final sets => l.lensThisWeek(l.lensSets(sets), l.lensSessions(now.sessions)),
    };
    final most = weeks.reduce(max);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${line.label}. $summary. ${l.lensWeekByWeek(weeks.join(', '))}',
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(line.label, style: textTheme.titleSmall, maxLines: 1, overflow: .ellipsis),
                Text(
                  summary,
                  style: textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
              ],
            ),
          ),
          // eight thin weeks beside the words rather than under them: a line
          // stays one line tall, and the bars keep their width at any font
          SizedBox(
            width: _lensBarsWidth,
            height: 28,
            child: Row(
              crossAxisAlignment: .end,
              spacing: 3,
              children: [
                for (final (index, sets) in weeks.indexed)
                  Expanded(
                    child: Container(
                      // an empty week is a sliver, so the row still reads as
                      // eight weeks rather than as gaps
                      height: switch (sets) {
                        0 => 2,
                        _ => 28 * sets / most,
                      },
                      decoration: BoxDecoration(
                        color: switch (index == weeks.length - 1) {
                          true => primary,
                          false => primary.withValues(alpha: .4),
                        },
                        borderRadius: const .vertical(top: .circular(2)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
