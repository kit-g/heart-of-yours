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
/// shaded on the body and listed beside it.
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

class _MuscleMapCardState extends State<_MuscleMapCard> {
  /// The window, in days, ending today.
  final _days = ValueNotifier(7);

  /// One read per window, kept until the history changes, so flipping between
  /// the two windows does not query again or flash a spinner.
  final _volumes = <int, Future<MuscleVolume>>{};

  @override
  void didUpdateWidget(covariant _MuscleMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.workouts, widget.workouts)) _volumes.clear();
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<MuscleVolume> _volume(int days) {
    return _volumes[days] ??= () async {
      final now = DateTime.now();
      // whole calendar days, today included — calendar arithmetic rather than
      // a Duration, so the window survives a DST change
      final from = DateTime(now.year, now.month, now.day - (days - 1));
      final to = DateTime(now.year, now.month, now.day + 1);
      return muscleVolume(await Stats.of(context).getMuscleSets(from, to));
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return ValueListenableBuilder<int>(
      valueListenable: _days,
      builder: (context, days, _) {
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
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 7, label: Text(l.lastSevenDays)),
                      ButtonSegment(value: 30, label: Text(l.lastThirtyDays)),
                    ],
                    selected: {days},
                    onSelectionChanged: (selection) => _days.value = selection.first,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<MuscleVolume>(
              future: _volume(days),
              builder: (context, snapshot) {
                return switch (snapshot.data) {
                  MuscleVolume volume => _MuscleMapBody(volume: volume),
                  null => const SizedBox(
                    height: _tileHeaderHeight * 2,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                };
              },
            ),
          ],
        );
      },
    );
  }
}

/// The figures and the list: side by side on the band's own two-tile split, so
/// they line up with the chart and goals tiles above; stacked below that.
class const _MuscleMapBody({
  required final MuscleVolume volume,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final (:sets, :unmapped) = volume;

    final ranked = sets.entries.where((entry) => entry.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final most = ranked.firstOrNull?.value ?? 0;

    // Shaded by share of the busiest group, with a floor so one set still
    // shows. The accent the exercise page uses for "primary", at strengths.
    Color shade(double count) => colorScheme.tertiary.withValues(alpha: .2 + .8 * count / most);
    final colors = {
      for (final muscle in MuscleCatalog.all)
        if (sets[muscle.group] case double count when count > 0) muscle: shade(count),
    };

    final note = switch (unmapped) {
      0 => null,
      int count => Padding(
        padding: const .only(top: 8),
        child: Text(
          l.muscleMapUnmapped(count),
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    };

    final list = switch (ranked) {
      [] => Center(
        child: Padding(
          padding: const .all(16),
          child: Text(l.muscleMapEmpty, style: textTheme.bodyMedium, textAlign: .center),
        ),
      ),
      _ => Column(
        mainAxisSize: .min,
        children: [
          for (final MapEntry(key: group, value: count) in ranked)
            _GroupRow(label: group.label(l), count: count, share: count / most, color: shade(count)),
        ],
      ),
    };

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
                    Expanded(child: _Figures(colors: colors)),
                    Expanded(
                      child: _Panel(child: SingleChildScrollView(child: list)),
                    ),
                  ],
                ),
              ),
              ?note,
            ],
          ),
          false => Column(
            crossAxisAlignment: .stretch,
            spacing: 8,
            children: [
              SizedBox(
                height: min(width * 4 / 5, 320),
                child: _Figures(colors: colors),
              ),
              _Panel(child: list),
              ?note,
            ],
          ),
        };
      },
    );
  }
}

/// Front and back, shaded. One image to assistive tech: the list carries the
/// numbers in words.
class const _Figures({
  required final Map<MuscleInfo, Color> colors,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: L.of(context).muscleMapFigure,
      excludeSemantics: true,
      child: _Panel(
        child: Row(
          spacing: 8,
          children: [
            for (final view in [AtlasAsset.musclesFront, AtlasAsset.musclesBack])
              Expanded(
                child: BodyAtlasView<MuscleInfo>(
                  view: view,
                  resolver: const MuscleResolver(),
                  colorMapping: colors,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The quiet inset the band's tiles draw their content on.
class const _Panel({
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(12)),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      padding: const .all(12),
      child: child,
    );
  }
}

/// One group: its name, its sets, and a bar in the shade the map paints it —
/// the legend and the data in one row.
class const _GroupRow({
  required final String label,
  required final double count,
  required final double share,
  required final Color color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    final l = L.of(context);
    final number = NumberFormat('#,##0.#', l.localeName).format(count);

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
                Text(number, style: textTheme.bodyMedium?.copyWith(fontFeatures: const [.tabularFigures()])),
              ],
            ),
            ExcludeSemantics(
              child: FractionallySizedBox(
                alignment: .centerLeft,
                widthFactor: share,
                child: Container(
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
