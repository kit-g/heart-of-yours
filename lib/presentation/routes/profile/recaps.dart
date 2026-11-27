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
  /// Every past month, with one of them open beside the list when the page
  /// has room for both.
  final ValueChanged<DateTime?> onRecaps;
  final ValueChanged<DateTime> onMonth;

  const new({required this.onRecaps, required this.onMonth});

  @override
  State<_RecapsSection> createState() => _RecapsSectionState();
}

class _RecapsSectionState extends State<_RecapsSection> {
  static const _feature = Feature.recaps;

  /// The months as read at a [Stats.revision]: they go stale when it moves.
  ({int revision, Future<Map<DateTime, int>> months})? _months;

  Future<Map<DateTime, int>> _readMonths(int revision) {
    if (_months case (revision: final at, :final months) when at == revision) return months;
    final months = Stats.of(context).getRecapMonths();
    _months = (revision: revision, months: months);
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final on = preferences.isOn(_feature);
    final revision = context.select<Stats, int>((stats) => stats.revision);

    final Widget? child = switch (preferences) {
      _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      _ when on || preferences.shouldOffer(_feature) => FutureBuilder<Map<DateTime, int>>(
        future: _readMonths(revision),
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

    // On a page wide enough for the months and a report side by side, last
    // month opens there, picked: its own page over the list would show the
    // same report twice, the second time on Back (#687). [band] is the slot's
    // width, inside the page's 16 each side.
    List<Widget> feature(double band) => [
      if (fresh)
        _RecapCard(
          month: lastMonth,
          onTap: switch (recapsSideBySide(band + 32)) {
            true => () => widget.onRecaps(lastMonth),
            false => () => widget.onMonth(lastMonth),
          },
        ),
      if (months.isNotEmpty) _RecapsEntry(onTap: () => widget.onRecaps(null)),
    ];

    final List<Widget> Function(double band) children = switch (on) {
      true => feature,
      // offered where the card would be, when it would be: a recap of a month
      // that has one is the thing being asked about
      false when fresh => (_) => [
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
      false => (_) => const <Widget>[],
    };

    return LayoutBuilder(
      builder: (_, constraints) {
        final band = constraints.maxWidth - 32;
        return switch (children(band)) {
          [] => const SizedBox.shrink(),
          final children => Padding(
            padding: const .only(left: 16, right: 16, bottom: 8),
            // as wide as the chart tile above, starting and ending on its
            // edges (#687): a readable measure left the card and the entry
            // short of it
            child: Align(
              alignment: .centerLeft,
              child: SizedBox(
                width: tileWidth(band),
                child: Column(crossAxisAlignment: .stretch, spacing: 8, children: children),
              ),
            ),
          ),
        };
      },
    );
  }
}

/// Last month in a line, quietly, for the first days of this one. Tapping it
/// opens the month.
class _RecapCard extends StatefulWidget {
  final DateTime month;
  final VoidCallback onTap;

  const new({required this.month, required this.onTap});

  @override
  State<_RecapCard> createState() => _RecapCardState();
}

class _RecapCardState extends State<_RecapCard> {
  /// The recap as read for a month at a [Stats.revision]: stale when either
  /// moves.
  ({(DateTime, int) key, Future<Recap> recap})? _recap;

  Future<Recap> _read(int revision) {
    final key = (widget.month, revision);
    if (_recap case (key: final at, :final recap) when at == key) return recap;
    final preferences = Preferences.of(context);
    final recap = Stats.of(context).getRecap(
      RecapPeriod.month(widget.month),
      firstWeekday: preferences.firstWeekday,
      weightUnit: preferences.weightUnit,
    );
    _recap = (key: key, recap: recap);
    return recap;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);

    return Semantics(
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
                        future: _read(context.select<Stats, int>((stats) => stats.revision)),
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

    return Material(
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
    );
  }
}
