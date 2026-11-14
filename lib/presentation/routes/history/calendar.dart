part of 'history.dart';

/// History as a calendar (#609): months scrolling up into the past from the
/// current one, a marked day for each day trained.
///
/// It is the page itself, not a dialog over it, so a marked day opens its
/// workout the way a card in the list does — [onTapWorkout], pushed on a
/// phone and in the detail pane on a tablet — and [selectedId] marks the day
/// the pane is showing.
class HistoryCalendar extends StatefulWidget {
  final void Function(Workout)? onTapWorkout;

  /// Id of the workout open in the detail pane; null in compact.
  final String? selectedId;

  /// The month list's controller: History's, so a navbar re-tap brings the
  /// current month back. Without one the calendar keeps its own.
  final ScrollController? controller;

  const new({super.key, this.onTapWorkout, this.selectedId, this.controller});

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  // a plain flag: it only debounces a request and must never cause a frame
  bool _pageScheduled = false;
  late final _latest = DateTime(DateTime.now().year, DateTime.now().month);

  void _loadOlder(Workouts workouts) {
    if (_pageScheduled || workouts.loadingMoreHistory || workouts.historyPageError || !workouts.hasMoreHistory) return;
    _pageScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageScheduled = false;
      if (!mounted) return;
      final current = Workouts.of(context);
      if (!current.loadingMoreHistory && !current.historyPageError && current.hasMoreHistory) {
        current.loadMoreHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final workouts = Workouts.watch(context);
    final byMonth = workouts.byMonth;
    final dates = byMonth.keys.map((key) => DateTime.parse('$key-01')).toList()..sort();
    final newest = dates.isNotEmpty && dates.last.isAfter(_latest) ? dates.last : _latest;
    final oldest = dates.firstOrNull ?? newest;
    final count = (newest.year - oldest.year) * 12 + newest.month - oldest.month + 1;
    final locale = L.of(context).localeName;
    // the user's first day (#339), counted the way Material's calendars do:
    // 0 is Sunday, so a DateTime weekday maps over by its remainder
    final firstWeekday = Preferences.watch(context).firstWeekday % 7;

    // Measured and capped: a seven-column grid stretched across a tablet's
    // pane is all gaps, so it keeps phone proportions and centres itself.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: calendarWidth),
        child: Column(
          children: [
            Padding(
              padding: const .symmetric(horizontal: 4, vertical: 12),
              child: Row(
                children: List.generate(7, (index) {
                  final day = DateTime(2024, 1, 7 + (firstWeekday + index) % 7);
                  return Expanded(
                    child: Semantics(
                      container: true,
                      label: DateFormat.EEEE(locale).format(day),
                      excludeSemantics: true,
                      child: Text(DateFormat.EEEEE(locale).format(day), textAlign: .center),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: widget.controller,
                reverse: true,
                // clear of the active workout's button, over the current month
                padding: const .only(bottom: 72),
                itemCount: count + 1,
                itemBuilder: (context, index) {
                  if (index >= count - 1) _loadOlder(workouts);
                  if (index == count) {
                    return _HistoryTail(
                      loading: workouts.loadingMoreHistory,
                      error: workouts.historyPageError,
                      hasMore: workouts.hasMoreHistory,
                      onRetry: () => workouts.loadMoreHistory(),
                    );
                  }
                  final month = DateTime(newest.year, newest.month - index);
                  final key = DateFormat('yyyy-MM').format(month);
                  // byMonth is newest-first: several sessions on a day share
                  // one mark and open the most recent
                  final days = <int, Workout>{
                    for (final workout in (byMonth[key] ?? const <Workout>[]).reversed) workout.start.day: workout,
                  };
                  return _CalendarMonth(
                    key: ValueKey(key),
                    month: month,
                    days: days,
                    firstWeekday: firstWeekday,
                    selectedId: widget.selectedId,
                    onOpen: widget.onTapWorkout,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarMonth extends StatelessWidget {
  final DateTime month;
  final Map<int, Workout> days;
  final int firstWeekday;
  final String? selectedId;
  final void Function(Workout)? onOpen;

  const new({
    super.key,
    required this.month,
    required this.days,
    required this.firstWeekday,
    this.selectedId,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final locale = L.of(context).localeName;
    final theme = Theme.of(context);
    final offset = (month.weekday % 7 - firstWeekday + 7) % 7;
    final length = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + length) / 7).ceil();
    return Padding(
      padding: const .fromLTRB(4, 16, 4, 16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const .fromLTRB(12, 0, 12, 16),
            child: Text(DateFormat.yMMM(locale).format(month), style: theme.textTheme.titleLarge),
          ),
          ...List.generate(
            rows,
            (row) => Row(
              children: List.generate(7, (column) {
                final day = row * 7 + column - offset + 1;
                if (day < 1 || day > length) return const Expanded(child: SizedBox(height: 48));
                final date = DateTime(month.year, month.month, day);
                final label = DateFormat.yMMMMEEEEd(locale).format(date);
                final number = Text('$day', style: theme.textTheme.bodyLarge);
                return Expanded(
                  child: SizedBox(
                    height: 52,
                    child: switch ((days[day], onOpen)) {
                      (Workout workout, void Function(Workout) open) => _MarkedDay(
                        label: '$label, ${L.of(context).editWorkout}',
                        selected: workout.id == selectedId,
                        onTap: () => open(workout),
                        child: number,
                      ),
                      _ => Semantics(
                        container: true,
                        label: label,
                        excludeSemantics: true,
                        child: Center(child: number),
                      ),
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// A day trained: filled, with a check, and outlined while the detail pane
/// shows its workout.
class _MarkedDay extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const new({required this.label, required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final ColorScheme(:primary, :onPrimary, :surfaceContainerHighest) = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: Stack(
            clipBehavior: .none,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: .center,
                decoration: BoxDecoration(
                  color: surfaceContainerHighest,
                  shape: .circle,
                  border: selected ? .all(color: primary, width: 2) : null,
                ),
                child: child,
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: primary, shape: .circle),
                  child: Icon(Icons.check, size: 14, color: onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
