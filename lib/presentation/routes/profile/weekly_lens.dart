part of 'profile.dart';

/// What the weekly sets card groups by (#341): the two keys over the same sets
/// (`docs/2026-10-11.pattern-lens.md`, rule 1), and pairs of patterns set
/// against each other (#342, rule 3).
enum _LensKey { patterns, muscles, balance }

/// The weeks the card reads: the eight of the workouts-per-week chart above.
const _lensWeeks = 8;

/// The lines shown before "Show all": the keys trained most this week.
const _lensLines = 6;

/// The weeks a balance pair counts: a window rather than one week, so a
/// pull day that fell on a Monday does not tip the pair on its own.
const _balanceWeeks = 4;

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
          // three choices beside the title outgrow a phone: the choices then
          // take a line of their own under it
          child: Wrap(
            alignment: .spaceBetween,
            crossAxisAlignment: .center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(l.lensTitle, style: textTheme.titleLarge, maxLines: 2, overflow: .ellipsis),
              ValueListenableBuilder<_LensKey>(
                valueListenable: _key,
                builder: (_, key, _) {
                  // on a line of its own it can still outgrow a narrow phone
                  // at a large text size: it scrolls rather than overflows
                  return SingleChildScrollView(
                    scrollDirection: .horizontal,
                    child: SettingSwitcher<_LensKey>(
                      value: key,
                      onValueChanged: (value) => _key.value = value ?? key,
                      children: {
                        .patterns: Text(l.lensPatterns),
                        .muscles: Text(l.lensMuscles),
                        .balance: Text(l.lensBalance),
                      },
                    ),
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
                  Widget lensBody(List<_LensLine> lines, String empty) {
                    return _WeeklyLensBody(
                      lines: lines,
                      unfolded: _unfolded.value,
                      onUnfold: (unfolded) => _unfolded.value = unfolded,
                      empty: empty,
                    );
                  }

                  return switch (_key.value) {
                    .patterns => lensBody(
                      _lines(
                        countByWeek(rows, weeks: _lensWeeks, now: now, keysOf: patternsOf, firstWeekday: firstWeekday),
                        (pattern) => patternLabel(pattern, l),
                      ),
                      switch (rows.isEmpty) {
                        true => l.lensNothingYet,
                        false => l.lensNoPatternsYet,
                      },
                    ),
                    .muscles => lensBody(
                      _lines(
                        countByWeek(
                          rows,
                          weeks: _lensWeeks,
                          now: now,
                          keysOf: muscleGroupsOf,
                          firstWeekday: firstWeekday,
                        ),
                        (group) => group.label(l),
                      ),
                      l.lensNothingYet,
                    ),
                    .balance => _WeeklyBalanceBody(
                      counts: countBalance(
                        rows,
                        pairs: balancePairs,
                        weeks: lastWeeksOf(_balanceWeeks, now: now, firstWeekday: firstWeekday),
                        weekOfStart: (start) => weekOf(start, firstWeekday: firstWeekday),
                      ),
                    ),
                  };
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
    ].where((line) => wholeSets(total(line)) > 0).toList()..sort(
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
    final weeks = [for (final week in line.weeks) wholeSets(week.sets)];
    final now = line.weeks.last;
    final summary = switch (wholeSets(now.sets)) {
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

/// Balance (#342): pairs of patterns set against each other over the last
/// four weeks, two bars a pair. Counts and nothing more: push against pull is
/// coaching practice, not a finding, so the card says what was done and
/// leaves the verdict to the user. A pair with too little behind it says so
/// rather than drawing one good week as a lopsided habit.
class const _WeeklyBalanceBody({
  required final List<BalanceCount> counts,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, colorScheme: ColorScheme(:onSurfaceVariant)) = Theme.of(context);
    final trained = counts.where((count) => (count.left + count.right).round() > 0).toList();

    return Column(
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        Text(
          switch (trained.isEmpty) {
            true => l.balanceNothingYet,
            false => l.balanceWindow,
          },
          style: textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
        ),
        if (trained.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 16.0;
              final columns = columnsFor(constraints.maxWidth, maxExtent: _maxChartCardWidth);
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 16,
                children: [
                  for (final count in trained)
                    SizedBox(
                      width: width,
                      child: _BalancePairTile(count: count),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// What a side of a pair is called: the four sides that span several
/// patterns have words of their own, and a side of one pattern is that
/// pattern. A side content adds later names itself through [patternLabel]'s
/// fallback rather than shipping blank.
String _sideLabel(BalanceSide side, L l) {
  return switch (side.key) {
    'push' => l.balancePush,
    'pull' => l.balancePull,
    'hinge' => l.balanceHinge,
    'squat' => l.balanceSquat,
    final key => patternLabel(key, l),
  };
}

/// One pair: its name, then each side's sets as a bar against the larger
/// side, in whole numbers.
class const _BalancePairTile({
  required final BalanceCount count,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, colorScheme: ColorScheme(:onSurfaceVariant)) = Theme.of(context);
    final BalanceCount(:pair, :left, :right) = count;
    final (leftLabel, rightLabel) = (_sideLabel(pair.left, l), _sideLabel(pair.right, l));
    final (leftSets, rightSets) = (left.round(), right.round());

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: switch (count.enough) {
        true => l.balanceSides(leftLabel, l.lensSets(leftSets), rightLabel, l.lensSets(rightSets)),
        false => '${l.balancePair(leftLabel, rightLabel)}. ${l.balanceNotEnough}',
      },
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 4,
        children: [
          Text(l.balancePair(leftLabel, rightLabel), style: textTheme.titleSmall, maxLines: 1, overflow: .ellipsis),
          ...switch (count.enough) {
            true => [
              _BalanceSideBar(label: leftLabel, sets: leftSets, most: max(leftSets, rightSets)),
              _BalanceSideBar(label: rightLabel, sets: rightSets, most: max(leftSets, rightSets)),
            ],
            false => [
              Text(l.balanceNotEnough, style: textTheme.bodySmall?.copyWith(color: onSurfaceVariant)),
            ],
          },
        ],
      ),
    );
  }
}

/// A side's name, its bar, and its sets.
class const _BalanceSideBar({
  required final String label,
  required final int sets,
  required final int most,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, colorScheme: ColorScheme(:primary, :surfaceContainerHighest, :onSurfaceVariant)) =
        Theme.of(context);
    final small = textTheme.bodySmall?.copyWith(color: onSurfaceVariant);

    return Row(
      spacing: 8,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: small, maxLines: 1, overflow: .ellipsis),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const .all(.circular(2)),
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: surfaceContainerHighest,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: switch (most) {
                      0 => 0,
                      _ => sets / most,
                    },
                    heightFactor: 1,
                    child: ColoredBox(color: primary),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text('$sets', style: small, textAlign: .end),
        ),
      ],
    );
  }
}
