part of 'profile.dart';

/// The days at the start of a month the last one's recap shows on the
/// profile: long enough to be found by someone who trains twice a week,
/// short enough that it is gone before it is furniture.
const _recapDays = 7;

/// Recaps' slot on the profile (#154, `docs/2026-10-18.recaps.md`).
///
/// Off — declined, left unanswered, or switched off in Settings — it is an
/// empty sliver that reads nothing, and the profile is what it was before
/// recaps existed. Otherwise it holds the one offer, the one notice after a
/// no, or the feature: last month's card in a month's first days, and the way
/// to every past month.
class _RecapsSection extends StatefulWidget {
  /// Only its identity is read: [Stats] replaces it whenever a workout is
  /// finished or deleted, which is when the months behind the slot go stale.
  final WorkoutAggregation workouts;
  final VoidCallback onRecaps;
  final ValueChanged<DateTime> onMonth;

  const new({required this.workouts, required this.onRecaps, required this.onMonth});

  @override
  State<_RecapsSection> createState() => _RecapsSectionState();
}

class _RecapsSectionState extends State<_RecapsSection> {
  static const _feature = Feature.recaps;

  Future<Map<DateTime, int>>? _months;

  @override
  void didUpdateWidget(covariant _RecapsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.workouts, widget.workouts)) _months = null;
  }

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final on = preferences.isOn(_feature);

    final Widget? child = switch (preferences) {
      _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      _ when on || preferences.shouldOffer(_feature) => FutureBuilder<Map<DateTime, int>>(
        future: _months ??= Stats.of(context).getRecapMonths(),
        builder: (context, snapshot) => switch (snapshot.data) {
          final months? => _slot(context, preferences, months, on: on),
          null => const SizedBox.shrink(),
        },
      ),
      _ => null,
    };

    return SliverToBoxAdapter(
      child: switch (child) {
        Widget child => child,
        null => const SizedBox.shrink(),
      },
    );
  }

  /// What the slot holds once the months are read: nothing, when there is
  /// nothing to show.
  Widget _slot(BuildContext context, Preferences preferences, Map<DateTime, int> months, {required bool on}) {
    final now = clock.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    // last month had training, and this one has only just begun
    final fresh = now.day <= _recapDays && months.containsKey(lastMonth);

    final children = switch (on) {
      true => [
        if (fresh) _RecapCard(month: lastMonth, workouts: widget.workouts, onTap: () => widget.onMonth(lastMonth)),
        if (months.isNotEmpty) _RecapsEntry(onTap: widget.onRecaps),
      ],
      // offered where the card would be, when it would be: a recap of a month
      // that has one is the thing being asked about
      false when fresh => [
        FeatureOffer(
          key: AppKeys.recapsOffer,
          acceptKey: AppKeys.recapsAccept,
          declineKey: AppKeys.recapsDecline,
          icon: Icons.insights_rounded,
          title: L.of(context).recapsOfferTitle,
          body: L.of(context).recapsOfferBody,
          onAnswer: (yes) => preferences.answerOffer(_feature, yes: yes),
          onShown: () => preferences.markOffered(_feature),
        ),
      ],
      false => const <Widget>[],
    };

    return switch (children) {
      [] => const SizedBox.shrink(),
      _ => Padding(
        padding: const .only(left: 16, right: 16, bottom: 8),
        child: Column(crossAxisAlignment: .stretch, spacing: 8, children: children),
      ),
    };
  }
}

/// Last month in a line, quietly, for the first days of this one. Tapping it
/// opens the month.
class _RecapCard extends StatefulWidget {
  final DateTime month;
  final WorkoutAggregation workouts;
  final VoidCallback onTap;

  const new({required this.month, required this.workouts, required this.onTap});

  @override
  State<_RecapCard> createState() => _RecapCardState();
}

class _RecapCardState extends State<_RecapCard> {
  Future<Recap>? _recap;

  @override
  void didUpdateWidget(covariant _RecapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.workouts, widget.workouts) || oldWidget.month != widget.month) _recap = null;
  }

  Future<Recap> _read() {
    final preferences = Preferences.of(context);
    return _recap ??= Stats.of(context).getRecap(
      RecapPeriod.month(widget.month),
      firstWeekday: preferences.firstWeekday,
      weightUnit: preferences.weightUnit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);

    return Align(
      alignment: .centerLeft,
      child: ConstrainedBox(
        // a line of prose and a chevron: an iPad's width would strand them
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Semantics(
          button: true,
          label: l.recapOpen,
          child: Material(
            type: .transparency,
            child: InkWell(
              key: AppKeys.recapCard,
              borderRadius: const .all(.circular(12)),
              onTap: widget.onTap,
              child: Ink(
                decoration: BoxDecoration(
                  border: .all(color: dividerColor, width: .5),
                  borderRadius: const .all(.circular(12)),
                ),
                padding: const .all(16),
                child: Row(
                  spacing: 12,
                  children: [
                    Icon(Icons.insights_rounded, color: colorScheme.primary),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: 2,
                        children: [
                          Text(
                            '${l.recapLastMonth} · ${monthTitle(l, widget.month)}',
                            style: textTheme.titleMedium,
                          ),
                          FutureBuilder<Recap>(
                            future: _read(),
                            builder: (context, snapshot) => Text(
                              switch (snapshot.data) {
                                final recap? => recapSummary(l, recap),
                                // the line's height held, so nothing jumps
                                null => '',
                              },
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The way to every past month, under the profile, while there is any.
class _RecapsEntry extends StatelessWidget {
  final VoidCallback onTap;

  const new({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Align(
      alignment: .centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Material(
          type: .transparency,
          child: InkWell(
            key: AppKeys.recapsEntry,
            borderRadius: const .all(.circular(12)),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                spacing: 12,
                children: [
                  Icon(Icons.history_rounded, color: colorScheme.onSurfaceVariant),
                  Expanded(child: Text(l.recaps, style: textTheme.titleMedium)),
                  Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
