part of 'recaps.dart';

/// Width of the month list beside the open report, when the page has room for
/// both: a month's name and its count, and no more.
const _listWidth = 320.0;

/// Every finished month with workouts in it, newest first (#154): the way
/// back to any recap, from the entry under the profile.
///
/// Where the page is wide enough for a list and a report side by side — an
/// iPad either way up — it is both (#687): the months on the left, the one
/// picked open beside them, the newest to begin with so the pane is never
/// empty. Narrower, a month opens on its own page, as on a phone.
class RecapsPage extends StatefulWidget {
  final ValueChanged<DateTime> onMonth;

  const new({super.key, required this.onMonth});

  @override
  State<RecapsPage> createState() => _RecapsPageState();
}

class _RecapsPageState extends State<RecapsPage> {
  late final Future<Map<DateTime, int>> _months = Stats.of(context).getRecapMonths();

  /// The month open beside the list, once one has been picked there.
  final _picked = ValueNotifier<DateTime?>(null);

  @override
  void dispose() {
    _picked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // room for the list and a report no narrower than a profile tile: an
        // iPad held upright clears it, a phone and a 7" tablet's pane do not
        final split = constraints.maxWidth >= _listWidth + minTileWidth;

        return FutureBuilder<Map<DateTime, int>>(
          future: _months,
          builder: (context, snapshot) {
            final list = switch (snapshot.data) {
              null => const Center(child: CircularProgressIndicator()),
              final months when months.isEmpty => Padding(
                padding: const .all(16),
                child: Text(
                  l.recapsNone,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
              final months => ValueListenableBuilder<DateTime?>(
                valueListenable: _picked,
                builder: (context, picked, _) {
                  final open = switch (split) {
                    true => picked ?? months.keys.first,
                    false => null,
                  };
                  return ListView(
                    padding: const .symmetric(vertical: 8),
                    children: [
                      for (final MapEntry(key: month, value: workouts) in months.entries)
                        ListTile(
                          title: Text(monthTitle(l, month)),
                          subtitle: Text(l.recapWorkoutsCount(workouts)),
                          // beside the report a month opens in place, not onward
                          trailing: split ? null : const Icon(Icons.chevron_right_rounded),
                          selected: month == open,
                          onTap: switch (split) {
                            true => () => _picked.value = month,
                            false => () => widget.onMonth(month),
                          },
                        ),
                    ],
                  );
                },
              ),
            };

            return switch ((split, snapshot.data)) {
              (true, final Map<DateTime, int> months) when months.isNotEmpty => Row(
                crossAxisAlignment: .stretch,
                children: [
                  SizedBox(
                    width: _listWidth,
                    child: Scaffold(
                      appBar: AppBar(title: Text(l.recaps)),
                      body: list,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: ValueListenableBuilder<DateTime?>(
                      valueListenable: _picked,
                      builder: (_, picked, _) {
                        final month = picked ?? months.keys.first;
                        // keyed, so a newly picked month reads its own recap
                        return MonthlyReportPage(key: ValueKey(month), month: month, implyBack: false);
                      },
                    ),
                  ),
                ],
              ),
              _ => Scaffold(
                appBar: AppBar(title: Text(l.recaps)),
                body: Align(
                  alignment: .topCenter,
                  child: SizedBox(
                    // a list of months: across a tablet the count drifts away
                    // from the month it belongs to
                    width: math.min(constraints.maxWidth, readableWidth),
                    child: list,
                  ),
                ),
              ),
            };
          },
        );
      },
    );
  }
}
