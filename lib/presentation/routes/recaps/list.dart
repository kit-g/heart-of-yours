part of 'recaps.dart';

/// Width of the month list beside the open report, when the page has room for
/// both: a month's name and its count, and no more.
const _listWidth = 320.0;

/// The line between the list and the report.
const _dividerWidth = 1.0;

/// Whether a Recaps page [width] wide has room for the month list and a report
/// beside it no narrower than a profile tile: an iPad either way up does, a
/// phone and a 7" tablet's pane do not.
///
/// Public so the profile's recap card can tell, from the same width, whether
/// last month opens beside the list or on a page of its own.
bool recapsSideBySide(double width) => width >= _listWidth + _dividerWidth + minTileWidth;

/// Every finished month with workouts in it, newest first (#154): the way
/// back to any recap, from the entry under the profile.
///
/// Where the page is wide enough ([recapsSideBySide]), a month opens beside
/// the list (#687) in the app's one list-and-detail ([MasterDetail], #685):
/// the list alone until one is picked, or [month] if one was asked for, and
/// a tap opens another in place. Narrower, a month opens on its own page, as
/// on a phone. The list is one child throughout, so it keeps its place across
/// a resize.
class RecapsPage extends StatefulWidget {
  /// The month to open beside the list, by its first day.
  final DateTime? month;

  /// A month to open on its own page, where there is no room beside the list.
  final ValueChanged<DateTime> onMonth;

  /// A month opened beside the list: no route changes, so whoever counts
  /// screens hears it here.
  final ValueChanged<DateTime>? onMonthShown;

  const new({super.key, this.month, required this.onMonth, this.onMonthShown});

  @override
  State<RecapsPage> createState() => _RecapsPageState();
}

class _RecapsPageState extends State<RecapsPage> {
  late final Future<Map<DateTime, int>> _months = Stats.of(context).getRecapMonths();

  /// The month open beside the list, if any.
  late final _picked = ValueNotifier<DateTime?>(widget.month);

  @override
  void dispose() {
    _picked.dispose();
    super.dispose();
  }

  void _pick(DateTime month) {
    _picked.value = month;
    widget.onMonthShown?.call(month);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = recapsSideBySide(constraints.maxWidth);

        return FutureBuilder<Map<DateTime, int>>(
          future: _months,
          builder: (context, snapshot) {
            final months = snapshot.data;
            final list = Align(
              alignment: .topCenter,
              child: SizedBox(
                // a list of months: across a tablet the count drifts away
                // from the month it belongs to
                width: math.min(constraints.maxWidth, readableWidth),
                child: _list(context, months, split: split),
              ),
            );
            return Scaffold(
              // the page's, across the list and what opens beside it
              appBar: AppBar(title: Text(l.recaps)),
              body: switch (split) {
                false => list,
                true => ValueListenableBuilder<DateTime?>(
                  valueListenable: _picked,
                  builder: (context, picked, _) => MasterDetail(
                    masterWidth: (_) => _listWidth,
                    maxMasterWidth: readableWidth,
                    master: list,
                    detail: switch ((picked, months)) {
                      // keyed, so a newly picked month reads its own recap
                      (final DateTime month, final months?) when months.containsKey(month) => MonthlyReportPage(
                        key: ValueKey(month),
                        month: month,
                        implyBack: false,
                        onClose: () => _picked.value = null,
                      ),
                      _ => null,
                    },
                  ),
                ),
              },
            );
          },
        );
      },
    );
  }

  Widget _list(BuildContext context, Map<DateTime, int>? months, {required bool split}) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return switch (months) {
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
          final open = split ? picked : null;
          return ListView(
            // beside the report, the report's scroll is the page's: two
            // scrollables on one primary controller break Page Up and Down
            primary: !split,
            padding: const .symmetric(vertical: 8),
            children: [
              for (final MapEntry(key: month, value: workouts) in months.entries)
                ListTile(
                  title: Text(monthTitle(l, month)),
                  subtitle: Text(l.recapWorkoutsCount(workouts)),
                  // beside the report a month opens in place, not onward
                  trailing: split ? null : const Icon(Icons.chevron_right_rounded),
                  selected: month == open,
                  onTap: split ? () => _pick(month) : () => widget.onMonth(month),
                ),
            ],
          );
        },
      ),
    };
  }
}
