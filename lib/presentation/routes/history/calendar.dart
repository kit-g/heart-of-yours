part of 'history.dart';

/// A persistent calendar route: opening an editor never replaces its scroll state.
class HistoryCalendar extends StatefulWidget {
  final Future<void> Function(Iterable<Media>, {required int startingIndex, String? workoutId})? onTapImage;

  const new({super.key, this.onTapImage});

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  final _scroll = ScrollController();
  final _opening = ValueNotifier<String?>(null);
  bool _pageScheduled = false;
  late final _latest = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void dispose() {
    _scroll.dispose();
    _opening.dispose();
    super.dispose();
  }

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

  Future<void> _open(Workout workout) async {
    if (_opening.value != null) return;
    _opening.value = workout.id;
    try {
      final workouts = Workouts.of(context);
      final found = await workouts.fetchWorkout(workout.id);
      if (!mounted) return;
      final copy = workouts.lookup(workout.id);
      if (!found || copy == null) {
        snack(context, L.of(context).historyLoadMoreError);
        return;
      }
      // Preserve session and set IDs while keeping unsaved edits off the cache.
      final editable = Workout.fromJson(copy.toMap());
      _opening.value = null;
      await showDialog<void>(
        context: context,
        // PopScope guards back and the editor's close action; barrier dismissal
        // bypasses that guard on some platforms, so it is deliberately disabled.
        barrierDismissible: false,
        builder: (editorContext) => Dialog(
          shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
          clipBehavior: .antiAlias,
          insetPadding: const .all(16),
          constraints: const BoxConstraints(maxWidth: dialogWidth, maxHeight: 800),
          child: WorkoutEditor(
            copy: editable,
            onTapImage: widget.onTapImage,
            onClose: () => Navigator.of(editorContext).pop(),
          ),
        ),
      );
    } catch (error) {
      if (mounted) snack(context, L.of(context).historyLoadMoreError);
    } finally {
      if (mounted) _opening.value = null;
    }
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
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final theme = Theme.of(context);

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
      clipBehavior: .antiAlias,
      insetPadding: const .symmetric(horizontal: 8, vertical: 24),
      constraints: const BoxConstraints(maxWidth: calendarDialogWidth, maxHeight: 800),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Stack(
              alignment: .center,
              children: [
                Center(child: Text(L.of(context).calendar, style: theme.textTheme.titleLarge)),
                Positioned(
                  left: 4,
                  child: IconButton(
                    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                    tooltip: L.of(context).close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
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
              controller: _scroll,
              reverse: true,
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
                final days = <int, Workout>{};
                // byMonth is newest-first: multiple sessions get one badge and
                // open the most recent session on that day.
                for (final workout in byMonth[key] ?? <Workout>[]) {
                  days.putIfAbsent(workout.start.day, () => workout);
                }
                return _CalendarMonth(
                  key: ValueKey(key),
                  month: month,
                  days: days,
                  firstWeekday: firstWeekday,
                  opening: _opening,
                  onOpen: _open,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarMonth extends StatelessWidget {
  final DateTime month;
  final Map<int, Workout> days;
  final int firstWeekday;
  final ValueNotifier<String?> opening;
  final void Function(Workout) onOpen;

  const new({
    super.key,
    required this.month,
    required this.days,
    required this.firstWeekday,
    required this.opening,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final locale = L.of(context).localeName;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
                final workout = days[day];
                final label = DateFormat.yMMMMEEEEd(locale).format(date);
                final number = Text('$day', style: theme.textTheme.bodyLarge);
                return Expanded(
                  child: SizedBox(
                    height: 52,
                    child: switch (workout) {
                      null => Semantics(
                        container: true,
                        label: label,
                        excludeSemantics: true,
                        child: Center(child: number),
                      ),
                      Workout workout => Semantics(
                        button: true,
                        label: '$label, ${L.of(context).editWorkout}',
                        onTap: () => onOpen(workout),
                        excludeSemantics: true,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onOpen(workout),
                          child: Center(
                            child: Stack(
                              clipBehavior: .none,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: .center,
                                  decoration: BoxDecoration(color: colors.surfaceContainerHighest, shape: .circle),
                                  child: number,
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: ValueListenableBuilder<String?>(
                                    valueListenable: opening,
                                    builder: (_, id, _) => Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(color: colors.primary, shape: .circle),
                                      child: switch (id == workout.id) {
                                        true => Padding(
                                          padding: const .all(3),
                                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary),
                                        ),
                                        false => Icon(Icons.check, size: 14, color: colors.onPrimary),
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
