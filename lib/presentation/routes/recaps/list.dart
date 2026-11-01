part of 'recaps.dart';

/// Every finished month with workouts in it, newest first (#154): the way
/// back to any recap, from the entry under the profile.
class RecapsPage extends StatefulWidget {
  final ValueChanged<DateTime> onMonth;

  const new({super.key, required this.onMonth});

  @override
  State<RecapsPage> createState() => _RecapsPageState();
}

class _RecapsPageState extends State<RecapsPage> {
  late final Future<Map<DateTime, int>> _months = Stats.of(context).getRecapMonths();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.recaps)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: .topCenter,
            child: SizedBox(
              // a list of months: across a tablet the count drifts away from
              // the month it belongs to
              width: math.min(constraints.maxWidth, readableWidth),
              child: FutureBuilder<Map<DateTime, int>>(
                future: _months,
                builder: (context, snapshot) {
                  return switch (snapshot.data) {
                    null => const Center(child: CircularProgressIndicator()),
                    final months when months.isEmpty => Padding(
                      padding: const .all(16),
                      child: Text(
                        l.recapsNone,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    final months => ListView(
                      padding: const .symmetric(vertical: 8),
                      children: [
                        for (final MapEntry(key: month, value: workouts) in months.entries)
                          ListTile(
                            title: Text(monthTitle(l, month)),
                            subtitle: Text(l.recapWorkoutsCount(workouts)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => widget.onMonth(month),
                          ),
                      ],
                    ),
                  };
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
