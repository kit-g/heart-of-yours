part of 'profile.dart';

/// The muscle map's slot on the profile (#136), and the first opt-in feature
/// (#138, `docs/opt-in.md`).
///
/// Four states, one of them nothing at all. Off — declined, left unanswered,
/// or switched off in Settings — the slot is an empty sliver and the profile
/// is exactly what it was before the feature existed: no header, no gap, no
/// greyed-out card. Otherwise it holds the one offer, the one notice after a
/// no, or the map itself.
class const _MuscleMapSection({
  required final WorkoutAggregation workouts,
}) extends StatelessWidget {
  static const _feature = Feature.muscleMap;

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);

    final Widget? child = switch (preferences) {
      _ when preferences.isOn(_feature) => _MuscleMapCard(workouts: workouts),
      _ when preferences.owesDeclineNotice(_feature) => _DeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      // Offered only once there is something to show: a map of nothing is no
      // way to decide whether you want one.
      _ when preferences.shouldOffer(_feature) && workouts.isNotEmpty => _MuscleMapOffer(
        onAnswer: (yes) => preferences.answerOffer(_feature, yes: yes),
        onShown: () => preferences.markOffered(_feature),
      ),
      _ => null,
    };

    return SliverToBoxAdapter(
      child: switch (child) {
        Widget child => Padding(
          padding: const .only(left: 16, right: 16, bottom: 8),
          child: child,
        ),
        null => const SizedBox.shrink(),
      },
    );
  }
}

/// The one ask. Showing it is what spends it: an offer the user scrolls past
/// and never answers is a no from the next launch on.
class _MuscleMapOffer extends StatefulWidget {
  final ValueChanged<bool> onAnswer;
  final VoidCallback onShown;

  const new({required this.onAnswer, required this.onShown});

  @override
  State<_MuscleMapOffer> createState() => _MuscleMapOfferState();
}

class _MuscleMapOfferState extends State<_MuscleMapOffer> {
  @override
  void initState() {
    super.initState();
    widget.onShown();
  }

  @override
  Widget build(BuildContext context) {
    final L(:muscleMapOfferTitle, :muscleMapOfferBody, :noThanks, :turnOn) = L.of(context);
    final ThemeData(:textTheme, :dividerColor) = Theme.of(context);

    return Align(
      alignment: .centerLeft,
      child: ConstrainedBox(
        // prose, so it gets a measure rather than an iPad's width
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Container(
          key: AppKeys.muscleMapOffer,
          decoration: BoxDecoration(
            border: .all(color: dividerColor, width: .5),
            borderRadius: const .all(.circular(12)),
          ),
          padding: const .all(16),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              Row(
                spacing: 12,
                children: [
                  const Icon(Icons.accessibility_new_rounded),
                  Expanded(child: Text(muscleMapOfferTitle, style: textTheme.titleMedium)),
                ],
              ),
              Text(muscleMapOfferBody, style: textTheme.bodyMedium),
              Row(
                mainAxisAlignment: .end,
                spacing: 8,
                children: [
                  TextButton(
                    key: AppKeys.muscleMapDecline,
                    onPressed: () => widget.onAnswer(false),
                    child: Text(noThanks),
                  ),
                  PrimaryButton.shrunk(
                    key: AppKeys.muscleMapAccept,
                    onPressed: () => widget.onAnswer(true),
                    child: Text(turnOn),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single line a no earns: where the way back is. Gone once closed, and
/// gone with the session either way — it is never shown again.
class const _DeclinedNotice({
  required final VoidCallback onDismiss,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final L(:featureDeclinedNotice, :close) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Align(
      alignment: .centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Row(
          key: AppKeys.featureDeclinedNotice,
          spacing: 8,
          children: [
            Icon(Icons.settings_outlined, size: 18, color: colorScheme.onSurfaceVariant),
            Expanded(
              child: Text(
                featureDeclinedNotice,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            // an IconButton for its 48pt target: the icon alone is 20
            IconButton(
              tooltip: close,
              onPressed: onDismiss,
              iconSize: 20,
              color: colorScheme.onSurfaceVariant,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// The muscle map itself: sets per muscle group over the last week or month,
/// shaded on the body and listed beside it, and week by week below.
///
/// The list is not decoration. The shading carries the numbers only by color,
/// which neither a screen reader nor a color-blind eye can read; the list says
/// the same thing in words.
class _MuscleMapCard extends StatefulWidget {
  /// Only its identity is read: [Stats] replaces it whenever a workout is
  /// finished or deleted, which is when the counts behind the map go stale.
  final WorkoutAggregation workouts;

  const new({required this.workouts});

  @override
  State<_MuscleMapCard> createState() => _MuscleMapCardState();
}

/// The heatmap's two spans, each at the grain that keeps its columns readable
/// on a phone: thirteen weeks is a training block at about 14pt a column;
/// fifty-two would be 4pt, so a year counts by month instead. The other
/// charts' 1M and All are left out — a month is the list's 30 days again, and
/// a column per year says nothing about balance.
enum _HeatmapRange {
  quarter(13),
  year(12);

  new(this.columns);

  final int columns;

  List<DateTime> buckets(DateTime now) {
    return switch (this) {
      .quarter => lastWeeks(columns, now: now),
      .year => lastMonths(columns, now: now),
    };
  }

  Map<DateTime, MuscleVolume> count(Iterable<MuscleSets> rows, List<DateTime> buckets) {
    return switch (this) {
      .quarter => weeklyMuscleVolume(rows, buckets),
      .year => monthlyMuscleVolume(rows, buckets),
    };
  }
}

/// The windows the switcher offers, in days.
const _windows = [7, 30];

class _MuscleMapCardState extends State<_MuscleMapCard> {
  /// The window, in days, ending today.
  final _days = ValueNotifier(_windows.first);

  /// One read covers every window and week the card shows, so flipping the
  /// switcher filters in memory: nothing to wait for, and the list can animate
  /// between the two instead of blinking through a spinner. Kept until the
  /// history changes.
  Future<List<MuscleSets>>? _rows;

  @override
  void didUpdateWidget(covariant _MuscleMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.workouts, widget.workouts)) _rows = null;
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<List<MuscleSets>> _read(DateTime now) {
    return _rows ??= () {
      final monthAgo = DateTime(now.year, now.month, now.day - (_windows.last - 1));
      final firstWeek = _HeatmapRange.quarter.buckets(now).first;
      final from = switch (firstWeek.isBefore(monthAgo)) {
        true => firstWeek,
        false => monthAgo,
      };
      return Stats.of(context).getMuscleSets(from, DateTime(now.year, now.month, now.day + 1));
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    final now = DateTime.now();

    return Column(
      key: AppKeys.muscleMapCard,
      crossAxisAlignment: .stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _tileHeaderHeight),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(l.muscleMap, style: textTheme.titleLarge, maxLines: 2, overflow: .ellipsis),
              ),
              // the house control for "pick one of a few", as in Settings
              ValueListenableBuilder<int>(
                valueListenable: _days,
                builder: (_, days, _) {
                  return SettingSwitcher<int>(
                    value: days,
                    onValueChanged: (value) => _days.value = value ?? days,
                    children: {
                      7: Text(l.lastSevenDays),
                      30: Text(l.lastThirtyDays),
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<MuscleSets>>(
          future: _read(now),
          builder: (context, snapshot) {
            return switch (snapshot.data) {
              List<MuscleSets> rows => ValueListenableBuilder<int>(
                valueListenable: _days,
                builder: (_, days, _) => _MuscleMapBody(rows: rows, days: days, now: now),
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
}

/// The figures and the list: side by side on the band's own two-tile split, so
/// they line up with the chart and goals tiles above; stacked below that. The
/// weekly heatmap runs underneath, across both.
class const _MuscleMapBody({
  required final List<MuscleSets> rows,
  required final int days,
  required final DateTime now,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    final (:sets, :unmapped) = muscleVolume(lastDays(rows, days, now: now));
    final month = muscleVolume(lastDays(rows, _windows.last, now: now)).sets;

    // One order for both windows and for the heatmap: the month's, ties broken
    // by the whole read (thirteen weeks). Ranked by whatever window is showing,
    // flipping the switcher would reshuffle every row instead of letting each
    // bar grow or shrink where it stands — and a group idle this week keeps its
    // row, at zero, which is itself the thing worth seeing.
    final span = muscleVolume(rows).sets;
    // and a full tie by the atlas's own order: List.sort is not stable, so
    // without it two equal groups could swap places between the two
    int rank(MuscleGroup a, MuscleGroup b) => switch ((
      (month[b] ?? 0).compareTo(month[a] ?? 0),
      (span[b] ?? 0).compareTo(span[a] ?? 0),
    )) {
      (0, 0) => a.index.compareTo(b.index),
      (0, int order) || (int order, _) => order,
    };
    final listed = month.keys.where((group) => (month[group] ?? 0) > 0).toList()..sort(rank);

    final most = sets.values.fold(0.0, max);
    // Shaded by share of the busiest group, with a floor so one set still
    // shows. The accent the exercise page uses for "primary", at strengths.
    Color shade(double count) => colorScheme.tertiary.withValues(alpha: .2 + .8 * count / most);
    final colors = {
      for (final muscle in MuscleCatalog.all)
        if (sets[muscle.group] case double count when count > 0) muscle: shade(count),
    };

    // what "Back 25.5" means, and — when there are some — the sets the
    // counting could not place
    final listHelp = switch (unmapped) {
      0 => l.muscleMapBreakdownHelp,
      int count => '${l.muscleMapBreakdownHelp}\n\n${l.muscleMapUnmapped(count)}',
    };

    final rowsOrEmpty = switch (listed) {
      [] => Center(
        child: Padding(
          padding: const .all(16),
          child: Text(l.muscleMapEmpty, style: textTheme.bodyMedium, textAlign: .center),
        ),
      ),
      _ => Column(
        mainAxisSize: .min,
        children: [
          for (final group in listed)
            _GroupRow(
              key: ValueKey(group),
              label: group.label(l),
              count: sets[group] ?? 0,
              share: switch (most) {
                0 => 0,
                _ => (sets[group] ?? 0) / most,
              },
              color: switch (sets[group]) {
                double count when count > 0 => shade(count),
                _ => colorScheme.surfaceContainerHighest,
              },
            ),
        ],
      ),
    };
    final list = Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          // clear of the corner's help button
          padding: const .only(right: _Help.size - 12, bottom: 4),
          child: Text(l.muscleMapBreakdown, style: textTheme.titleSmall),
        ),
        rowsOrEmpty,
      ],
    );

    final heatmap = Padding(
      padding: const .only(top: 8),
      child: _Heatmap(rows: rows, now: now, rank: rank),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return switch (tilesShareRow(width)) {
          true => Column(
            crossAxisAlignment: .stretch,
            children: [
              SizedBox(
                // the tiles' own height rule, on half the band
                height: min((width - tileGutter) / 2 * 4 / 5, _maxChartHeight),
                child: Row(
                  crossAxisAlignment: .stretch,
                  spacing: tileGutter,
                  children: [
                    Expanded(
                      child: _Figures(colors: colors, sets: sets),
                    ),
                    Expanded(
                      child: _Panel(
                        help: listHelp,
                        child: SingleChildScrollView(child: list),
                      ),
                    ),
                  ],
                ),
              ),
              heatmap,
            ],
          ),
          false => Column(
            crossAxisAlignment: .stretch,
            spacing: 8,
            children: [
              SizedBox(
                height: min(width * 4 / 5, 320),
                child: _Figures(colors: colors, sets: sets),
              ),
              _Panel(help: listHelp, child: list),
              heatmap,
            ],
          ),
        };
      },
    );
  }
}

/// Sets per group over time, a row per group and a column per week (or, over a
/// year, per month), oldest on the left: where the list answers "how much
/// lately", this answers "how steadily". One hue, more is stronger.
///
/// Two accessibility decisions shape it. The shades are stepped and floored
/// at 3:1 against the panel, and an empty week is a dot rather than a fill
/// (`heatmap_ink.dart`); measured on dark Ink, the first version's empty cells
/// were 1.05:1, and so invisible. And the tap target is the row, not the
/// cell: thirteen cells across a phone are 13pt each, under WCAG 2.5.8's 24.
/// A row's tooltip says what its semantics say — every value, oldest first.
class _Heatmap extends StatefulWidget {
  /// The card's read. It reaches back thirteen weeks; a year is read on
  /// demand, only once someone asks for it.
  final List<MuscleSets> rows;
  final DateTime now;

  /// The list's order, which the heatmap keeps so a group sits in the same
  /// place in both, whatever range either shows.
  final int Function(MuscleGroup a, MuscleGroup b) rank;

  const new({required this.rows, required this.now, required this.rank});

  @override
  State<_Heatmap> createState() => _HeatmapState();
}

/// One cell of the heatmap: a group, and a column counted from the oldest.
typedef _Cell = ({MuscleGroup group, int column});

class _HeatmapState extends State<_Heatmap> {
  final _range = ValueNotifier(_HeatmapRange.quarter);

  /// The cell last tapped (or dragged to), outlined and read out under the
  /// grid until it is tapped again or the range changes. Pinned rather than a
  /// tooltip: a tooltip opened by a tap is gone in a second and a half.
  final _selected = ValueNotifier<_Cell?>(null);

  /// A year of rows, read the first time 1Y is picked and kept until the
  /// card's own read is replaced — which is when the history changed.
  Future<List<MuscleSets>>? _year;

  @override
  void didUpdateWidget(covariant _Heatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rows, widget.rows)) _year = null;
  }

  @override
  void dispose() {
    _range.dispose();
    _selected.dispose();
    super.dispose();
  }

  Future<List<MuscleSets>> _rowsFor(_HeatmapRange range) {
    final now = widget.now;
    return switch (range) {
      .quarter => SynchronousFuture(widget.rows),
      .year => _year ??= Stats.of(context).getMuscleSets(
        range.buckets(now).first,
        DateTime(now.year, now.month, now.day + 1),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return ValueListenableBuilder<_HeatmapRange>(
      valueListenable: _range,
      builder: (context, range, _) {
        return Column(
          key: AppKeys.muscleMapHeatmap,
          crossAxisAlignment: .stretch,
          children: [
            _Panel(
              help: l.muscleMapHeatmapHelp,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  Padding(
                    // clear of the corner's help button
                    padding: const .only(right: _Help.size - 12, bottom: 8),
                    child: _Swap(
                      child: Text(
                        switch (range) {
                          .quarter => l.muscleMapWeekly,
                          .year => l.muscleMapMonthly,
                        },
                        key: ValueKey(range),
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ),
                  // Weeks and months are different grids — thirteen columns against
                  // twelve, and often a different set of rows — so one fades into
                  // the other while the box eases to its new height, rather than the
                  // card jumping between them.
                  AnimatedSize(
                    duration: _Swap.duration,
                    curve: _Swap.curve,
                    alignment: .topCenter,
                    child: FutureBuilder<List<MuscleSets>>(
                      future: _rowsFor(range),
                      builder: (context, snapshot) {
                        return _Swap(
                          child: switch (snapshot.data) {
                            List<MuscleSets> rows => KeyedSubtree(
                              key: ValueKey(range),
                              child: _grid(context, range, rows),
                            ),
                            null => const SizedBox(
                              key: ValueKey('loading'),
                              height: _HeatmapRow.height * 4,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Under the box, not in it: the switcher's track is the panel's own
            // fill, and inside the box it vanished. Out here it sits on the page,
            // like the 7/30 one above — and under the plot, as on the other charts.
            Center(
              child: SettingSwitcher<_HeatmapRange>(
                value: range,
                onValueChanged: (value) {
                  _selected.value = null;
                  _range.value = value ?? range;
                },
                children: {
                  .quarter: Text(l.chartRangeQuarter, style: _panelSmall(textTheme, colorScheme)),
                  .year: Text(l.chartRangeYear, style: _panelSmall(textTheme, colorScheme)),
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _grid(BuildContext context, _HeatmapRange range, List<MuscleSets> rows) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final numbers = NumberFormat('#,##0.#', l.localeName);
    final dates = switch (range) {
      .quarter => DateFormat.Md(l.localeName),
      .year => DateFormat.MMM(l.localeName),
    };

    final buckets = range.buckets(widget.now);
    final counted = range.count(rows, buckets);
    double count(MuscleGroup group, DateTime bucket) => counted[bucket]?.sets[group] ?? 0;
    double total(MuscleGroup group) => buckets.fold(0, (sum, bucket) => sum + count(group, bucket));

    final groups = MuscleGroup.values.where((group) => total(group) > 0).toList()..sort(widget.rank);
    final most = groups.fold(
      0.0,
      (most, group) => buckets.fold(most, (most, bucket) => max(most, count(group, bucket))),
    );
    final secondary = _panelSmall(textTheme, colorScheme);

    if (groups.isEmpty) {
      return Padding(
        padding: const .all(16),
        child: Text(l.muscleMapEmpty, style: textTheme.bodyMedium, textAlign: .center),
      );
    }

    return ValueListenableBuilder<_Cell?>(
      valueListenable: _selected,
      builder: (context, selected, _) {
        final caption = switch (selected) {
          (:MuscleGroup group, :int column) when groups.contains(group) && column < buckets.length =>
            l.muscleMapCellCaption(
              switch (range) {
                .quarter => l.muscleMapWeekOf(dates.format(buckets[column])),
                .year => DateFormat.yMMM(l.localeName).format(buckets[column]),
              },
              _setsOf(l, group, count(group, buckets[column])),
            ),
          _ => null,
        };

        return Column(
          crossAxisAlignment: .stretch,
          spacing: 2,
          children: [
            for (final group in groups)
              _HeatmapRow(
                label: group.label(l),
                // the row in words, for a screen reader: the cells are its picture
                summary: switch (range) {
                  .quarter => l.muscleMapWeeklyRow,
                  .year => l.muscleMapMonthlyRow,
                }(group.label(l), buckets.map((bucket) => numbers.format(count(group, bucket))).join(', ')),
                shares: [for (final bucket in buckets) count(group, bucket) / most],
                selected: switch (selected) {
                  (group: MuscleGroup picked, :int column) when picked == group => column,
                  _ => null,
                },
                onPick: (column, {required bool toggle}) {
                  _selected.value = switch ((toggle, selected)) {
                    (true, (group: MuscleGroup picked, column: int current))
                        when picked == group && current == column =>
                      null,
                    _ => (group: group, column: column),
                  };
                },
              ),
            // One line, two uses, so nothing below it moves on a tap: the
            // tapped cell read out, or else the span — the first column and
            // this one, since a label per column will not fit under 13pt cells.
            Padding(
              padding: const .only(left: _HeatmapRow.labelWidth, top: 4),
              child: switch (caption) {
                String caption => Text(caption, key: AppKeys.muscleMapCellCaption, style: secondary),
                null => ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Text(dates.format(buckets.first), style: secondary),
                      Text(dates.format(buckets.last), style: secondary),
                    ],
                  ),
                ),
              },
            ),
          ],
        );
      },
    );
  }
}

/// A crossfade between two versions of the same thing, the incoming one
/// settling in from a hair smaller. Both are laid out from the top, so a
/// shorter grid replacing a taller one does not float to the middle.
class const _Swap({
  required final Widget child,
}) extends StatelessWidget {
  static const duration = Duration(milliseconds: 280);
  static const curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      layoutBuilder: (current, previous) {
        return Stack(
          alignment: .topLeft,
          children: [...previous, ?current],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: .98, end: 1.0).animate(animation),
            alignment: .topCenter,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// One group across the heatmap's columns. The whole row is the tap target —
/// 24pt tall and as wide as the card, where one of its cells would be 13pt —
/// and where the finger lands picks the column; dragging along the row moves
/// through them.
class const _HeatmapRow({
  required final String label,
  required final String summary,

  /// Each column's count as a share of the grid's largest; zero is an empty
  /// week (or month).
  required final List<double> shares,

  /// The column outlined in this row, if the selection is here.
  required final int? selected,

  /// A column was picked; `toggle` when a tap (not a drag) may clear it.
  required final void Function(int column, {required bool toggle}) onPick,
}) extends StatelessWidget {
  static const height = 24.0;
  static const labelWidth = 96.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final panel = colorScheme.surfaceContainer;

    return Semantics(
      label: summary,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // the column under x: the label's strip picks the latest one
          int columnAt(double x) {
            final width = (constraints.maxWidth - labelWidth) / shares.length;
            return switch (x - labelWidth) {
              double offset when offset < 0 => shares.length - 1,
              double offset => (offset / width).floor().clamp(0, shares.length - 1),
            };
          }

          return GestureDetector(
            behavior: .opaque,
            onTapUp: (details) => onPick(columnAt(details.localPosition.dx), toggle: true),
            onHorizontalDragUpdate: (details) => onPick(columnAt(details.localPosition.dx), toggle: false),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(label, style: _panelSmall(textTheme, colorScheme), maxLines: 1, overflow: .ellipsis),
                  ),
                  Expanded(
                    child: Row(
                      spacing: _gap,
                      children: [
                        for (final (column, share) in shares.indexed)
                          Expanded(
                            child: Container(
                              margin: const .symmetric(vertical: 1),
                              // the picked cell: ringed in full ink, whether
                              // it holds sets or is an empty week's dot
                              foregroundDecoration: switch (column == selected) {
                                true => BoxDecoration(
                                  borderRadius: const .all(.circular(4)),
                                  border: .all(color: colorScheme.onSurface, width: 2),
                                ),
                                false => null,
                              },
                              decoration: switch (share) {
                                0 => null,
                                _ => BoxDecoration(
                                  borderRadius: const .all(.circular(4)),
                                  color: heatmapShade(colorScheme, panel, share),
                                ),
                              },
                              child: switch (share) {
                                0 => Center(
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(shape: .circle, color: heatmapEmpty(colorScheme)),
                                  ),
                                ),
                                _ => null,
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Front and back, shaded. One image to assistive tech: the list carries the
/// numbers in words.
///
/// Tapping a muscle names its group and that group's sets for the window on
/// show, in a label over the figures that fades after a few seconds — a
/// shortcut for anyone reading the body rather than the list, not the only
/// way to the number.
class _Figures extends StatefulWidget {
  final Map<MuscleInfo, Color> colors;

  /// The window's sets per group — what a tap reports.
  final Map<MuscleGroup, double> sets;

  const new({required this.colors, required this.sets});

  @override
  State<_Figures> createState() => _FiguresState();
}

class _FiguresState extends State<_Figures> {
  /// The group last tapped, while its label is up.
  final _tapped = ValueNotifier<MuscleGroup?>(null);
  Timer? _fade;

  static const _shown = Duration(seconds: 3);

  @override
  void dispose() {
    _fade?.cancel();
    _tapped.dispose();
    super.dispose();
  }

  void _onTap(MuscleInfo muscle) {
    _fade?.cancel();
    _tapped.value = muscle.group;
    _fade = Timer(_shown, () => _tapped.value = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final numbers = NumberFormat('#,##0.#', l.localeName);

    return _Panel(
      help: l.muscleMapFigureHelp,
      child: Stack(
        children: [
          // one image to assistive tech; the help beside it stays its own control
          Semantics(
            image: true,
            label: l.muscleMapFigure,
            excludeSemantics: true,
            child: Row(
              spacing: 8,
              children: [
                for (final view in [AtlasAsset.musclesFront, AtlasAsset.musclesBack])
                  Expanded(
                    child: BodyAtlasView<MuscleInfo>(
                      view: view,
                      resolver: const MuscleResolver(),
                      colorMapping: widget.colors,
                      onTapElement: _onTap,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<MuscleGroup?>(
                valueListenable: _tapped,
                builder: (_, group, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: switch (group) {
                      MuscleGroup group => Center(
                        key: ValueKey(group),
                        child: Container(
                          key: AppKeys.muscleMapFigureTip,
                          padding: const .symmetric(horizontal: 10, vertical: 6),
                          // the tooltip's own look: this is one, pinned
                          decoration: BoxDecoration(
                            color: colorScheme.inverseSurface,
                            borderRadius: const .all(.circular(6)),
                          ),
                          child: Text(
                            switch (widget.sets[group] ?? 0) {
                              double sets when sets % 1 == 0 => l.muscleMapMuscleSets(group.label(l), sets.toInt()),
                              double sets => l.muscleMapMuscleSetsFractional(group.label(l), numbers.format(sets)),
                            },
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onInverseSurface),
                          ),
                        ),
                      ),
                      null => const SizedBox.shrink(),
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The quiet inset the band's tiles draw their content on.
class const _Panel({
  required final Widget child,

  /// What the box shows, behind a "?" in its top-right corner.
  final String? help,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(12)),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      padding: const .all(12),
      child: child,
    );

    return switch (help) {
      String help => Stack(
        children: [
          box,
          Positioned(top: 0, right: 0, child: _Help(message: help)),
        ],
      ),
      null => box,
    };
  }
}

/// A "?" that explains the box it sits in. Tap, not long-press: a help mark
/// nobody knows to hold down explains nothing. The whole 48pt square answers
/// the tap, not only the 18pt glyph.
class const _Help({
  required final String message,
}) extends StatelessWidget {
  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    return _Tip(
      message: message,
      showDuration: const Duration(seconds: 10),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: Colors.transparent,
          child: Icon(
            Icons.help_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// One group: its name, its sets, and a bar in the shade the map paints it —
/// the legend and the data in one row. The number and the bar both animate, so
/// flipping the window reads as the same rows growing and shrinking.
class const _GroupRow({
  super.key,
  required final String label,
  required final double count,
  required final double share,
  required final Color color,
}) extends StatelessWidget {
  static const _duration = Duration(milliseconds: 350);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    final numbers = NumberFormat('#,##0.#', L.of(context).localeName);

    // one announcement per group — "Chest, 5" — rather than two fragments
    return MergeSemantics(
      child: Padding(
        padding: const .symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 4,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: textTheme.bodyMedium)),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: count),
                  duration: _duration,
                  curve: _curve,
                  builder: (_, value, _) {
                    // halves step through as halves, not as 3.7, 3.8…
                    final shown = (value * 2).round() / 2;
                    return Text(
                      numbers.format(shown),
                      style: textTheme.bodyMedium?.copyWith(fontFeatures: const [.tabularFigures()]),
                    );
                  },
                ),
              ],
            ),
            ExcludeSemantics(
              child: AnimatedFractionallySizedBox(
                duration: _duration,
                curve: _curve,
                alignment: .centerLeft,
                widthFactor: share,
                child: AnimatedContainer(
                  duration: _duration,
                  curve: _curve,
                  height: 4,
                  decoration: BoxDecoration(color: color, borderRadius: const .all(.circular(2))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on MuscleGroup {
  String label(L l) {
    return switch (this) {
      .legs => l.targetLegs,
      .adductors => l.muscleGroupAdductors,
      .hamstrings => l.muscleGroupHamstrings,
      .glutes => l.muscleGroupGlutes,
      .arms => l.targetArms,
      .neck => l.muscleGroupNeck,
      .back => l.targetBack,
      .core => l.targetCore,
      .shoulders => l.targetShoulders,
      .chest => l.targetChest,
    };
  }
}

/// Small text on a panel, in full ink. The theme's small style is muted, which
/// on the panel fill measured 4.05–4.44:1 in dark mode across the presets —
/// under the 4.5 twelve-point text needs.
TextStyle? _panelSmall(TextTheme textTheme, ColorScheme colorScheme) {
  return textTheme.bodySmall?.copyWith(color: colorScheme.onSurface);
}

/// The card's tooltips, all of them opened by a tap: opaque and inset from the
/// screen's edges. Flutter's default is a translucent grey band running edge
/// to edge, which over the list below it left both unreadable.
class const _Tip({
  required final String message,
  required final Widget child,
  final Duration? showDuration,
}) extends StatelessWidget {
  static BoxDecoration decoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.inverseSurface,
      borderRadius: const .all(.circular(8)),
    );
  }

  static TextStyle? textStyle(TextTheme textTheme, ColorScheme colorScheme) {
    return textTheme.bodySmall?.copyWith(color: colorScheme.onInverseSurface);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Tooltip(
      message: message,
      triggerMode: .tap,
      showDuration: showDuration,
      margin: const .symmetric(horizontal: 16),
      padding: const .symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: readableWidth),
      decoration: decoration(colorScheme),
      textStyle: textStyle(textTheme, colorScheme),
      child: child,
    );
  }
}

/// "Chest: 4 sets" — a group and its count, halves and all. Whole counts take
/// the plural forms; a half cannot, so it has its own phrasing.
String _setsOf(L l, MuscleGroup group, double sets) {
  return switch (sets % 1 == 0) {
    true => l.muscleMapMuscleSets(group.label(l), sets.toInt()),
    false => l.muscleMapMuscleSetsFractional(group.label(l), NumberFormat('#,##0.#', l.localeName).format(sets)),
  };
}
