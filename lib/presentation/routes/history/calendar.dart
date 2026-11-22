part of 'history.dart';

/// History as a calendar (#609): months scrolling up into the past from the
/// current one, a marked day for each day trained.
///
/// It is the page itself, not a dialog over it, so a marked day opens its
/// workout the way a card in the list does — [onTapWorkout], pushed on a
/// phone and in the detail pane on a tablet — after asking which, on a day of
/// several (#619). [selectedId] marks the day the pane is showing.
///
/// A day is also a way in (#618): an empty past day logs a workout on it,
/// today starts or logs one, and a trained day can take another. Logging is
/// Past workouts' (#530), so it is there only while that is on; the first
/// tap of an empty past day while it was never asked about is its one ask.
///
/// [paged], it shows one month at a time instead, swiped sideways (#739): the
/// same months and days, under a header that names the month and goes to
/// another. Nothing is later than the current month.
///
/// Under History's muscle-group filter (#610) only the workouts [shows] lets
/// through mark a day. A day whose workouts it all leaves out reads as plain
/// and does nothing: it is not empty, so it never offers to log as if it were.
class HistoryCalendar extends StatefulWidget {
  /// History's workouts by month, newest first ([Workouts.byMonth]), as the
  /// page already has them.
  final Map<String, List<Workout>> byMonth;

  /// Which workouts mark their day, under History's filter (#610); null, all.
  final bool Function(Workout)? shows;

  /// What workouts trained (#610), for the colours a day wears (#617): its
  /// muscle families, busiest first, up to three, with a key above the
  /// weekdays. Null — the library not read yet, or a caller with none — and
  /// days are marked without colour.
  final WorkoutGroups? trained;

  final void Function(Workout)? onTapWorkout;

  /// Id of the workout open in the detail pane; null in compact.
  final String? selectedId;

  /// The month list's controller: History's own, so a navbar re-tap brings
  /// the current month back. Without one the calendar keeps its own.
  final ScrollController? controller;

  /// One month at a time (#739), turned by [pages]: History's own controller,
  /// as [controller] is, and the calendar's own without one.
  final bool paged;
  final PageController? pages;

  /// Whether older history can still come, for the paged months, which have a
  /// page for it: what the server says ([Workouts.hasMoreHistory]), unless
  /// the page knows better.
  final bool? older;

  /// Logs a workout that already happened, on the given day (#618).
  final void Function(DateTime day)? onLogOn;

  /// Starts a new workout now (#618). Offered on today, while none is going.
  final VoidCallback? onStartWorkout;

  const new({
    super.key,
    required this.byMonth,
    this.shows,
    this.trained,
    this.onTapWorkout,
    this.selectedId,
    this.controller,
    this.paged = false,
    this.pages,
    this.older,
    this.onLogOn,
    this.onStartWorkout,
  });

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  // a plain flag: it only debounces a request and must never cause a frame
  bool _pageScheduled = false;
  final _ownController = ScrollController();
  final _ownPages = PageController();

  /// Today, on the user's clock: what a day's tap does turns on it (#618), so
  /// it moves at midnight and on coming back to the app, not only on a build.
  final _today = ValueNotifier(DateUtils.dateOnly(clock.now()));
  Timer? _midnight;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _turnTheDay);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    _today.dispose();
    _ownController.dispose();
    _ownPages.dispose();
    super.dispose();
  }

  void _turnTheDay() {
    _today.value = DateUtils.dateOnly(clock.now());
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = clock.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), _turnTheDay);
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

  /// The first tap of an empty past day while Past workouts was never asked
  /// about: the ask, and on yes straight on to logging that day.
  Future<void> _askThenLog(DateTime day) async {
    final L(:pastWorkoutsOfferTitle, :pastWorkoutsOfferBody) = L.of(context);
    final log = widget.onLogOn;
    final yes = await askInSheet(
      context,
      .pastWorkouts,
      icon: Icons.more_time_rounded,
      title: pastWorkoutsOfferTitle,
      body: pastWorkoutsOfferBody,
      offerKey: AppKeys.pastWorkoutsOffer,
      acceptKey: AppKeys.pastWorkoutsAccept,
      declineKey: AppKeys.pastWorkoutsDecline,
    );
    if (yes && mounted) log?.call(day);
  }

  @override
  Widget build(BuildContext context) {
    final workouts = Workouts.watch(context);
    final preferences = Preferences.watch(context);
    final byMonth = widget.byMonth;
    final logs = preferences.isOn(.pastWorkouts);
    final actions = (
      open: widget.onTapWorkout,
      log: logs ? widget.onLogOn : null,
      askToLog: switch ((widget.onLogOn, !logs && preferences.shouldOffer(.pastWorkouts))) {
        (void Function(DateTime) _, true) => _askThenLog,
        _ => null,
      },
      // one workout at a time: with one going, its button is the way there
      start: workouts.hasActiveWorkout ? null : widget.onStartWorkout,
      // while older pages are still to come, a day before the oldest workout
      // here may hold one not fetched yet: not a day to log on as if empty
      loadedFrom: switch ((workouts.hasMoreHistory, byMonth.values.lastOrNull?.lastOrNull)) {
        (true, final Workout oldest) => DateUtils.dateOnly(oldest.start.toLocal()),
        (true, null) => DateUtils.dateOnly(clock.now()),
        (false, _) => null,
      },
    );

    return ValueListenableBuilder<DateTime>(
      valueListenable: _today,
      builder: (context, today, _) => _months(context, workouts, preferences, actions, today),
    );
  }

  Widget _months(
    BuildContext context,
    Workouts workouts,
    Preferences preferences,
    _DayActions actions,
    DateTime today,
  ) {
    final byMonth = widget.byMonth;
    final dates = byMonth.keys.map((key) => DateTime.parse('$key-01')).toList()..sort();
    // the page can stay open across a month's end: today moves it on
    final latest = DateTime(today.year, today.month);
    // paged, nothing is later than the current month (#739)
    final newest = !widget.paged && dates.isNotEmpty && dates.last.isAfter(latest) ? dates.last : latest;
    final oldest = switch (dates.firstOrNull) {
      final DateTime first when first.isBefore(newest) => first,
      _ => newest,
    };
    final count = (newest.year - oldest.year) * 12 + newest.month - oldest.month + 1;
    final locale = L.of(context).localeName;
    // the user's first day (#339), counted the way Material's calendars do:
    // 0 is Sunday, so a DateTime weekday maps over by its remainder
    final firstWeekday = preferences.firstWeekday % 7;

    Widget tail() {
      return _HistoryTail(
        loading: workouts.loadingMoreHistory,
        error: workouts.historyPageError,
        hasMore: workouts.hasMoreHistory,
        onRetry: () => workouts.loadMoreHistory(),
      );
    }

    Widget month(DateTime month) {
      final key = DateFormat('yyyy-MM').format(month);
      // newest first, as byMonth has them; a workout counts on the
      // day it started, even one that ran past midnight
      final sessions = byMonth[key] ?? const <Workout>[];
      final shown = switch (widget.shows) {
        final bool Function(Workout) shows => sessions.where(shows).toList(),
        null => sessions,
      };
      final days = {
        for (final day in shown.map(_dayOf).toSet()) day: shown.where((workout) => _dayOf(workout) == day).toList(),
      };
      return _CalendarMonth(
        key: ValueKey(key),
        month: month,
        titled: !widget.paged,
        days: days,
        families: switch (widget.trained) {
          final WorkoutGroups trained => {
            for (final MapEntry(key: day, value: workouts) in days.entries)
              day: _ranked(trained.setsByFamily(workouts)),
          },
          null => const {},
        },
        // trained, but none of it under the filter
        hidden: sessions.map(_dayOf).toSet().difference(days.keys.toSet()),
        firstWeekday: firstWeekday,
        selectedId: widget.selectedId,
        actions: actions,
        today: today,
      );
    }

    final weekdays = Padding(
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
    );

    // Measured and capped: a seven-column grid stretched across a tablet's
    // pane is all gaps, so it keeps phone proportions and centres itself.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: calendarWidth),
        child: Column(
          children: [
            // always there, so nothing below it moves when the colours arrive
            const Padding(
              padding: .fromLTRB(12, 8, 12, 0),
              child: FamilyLegend(),
            ),
            // paged, right over the days, under the month's name
            if (!widget.paged) weekdays,
            Expanded(
              child: switch (widget.paged) {
                true => _MonthPages(
                  pages: widget.pages ?? _ownPages,
                  newest: newest,
                  count: count,
                  today: today,
                  // older ones are still to come: a page after the oldest
                  // month brings them
                  more: widget.older ?? workouts.hasMoreHistory,
                  onOldest: () => _loadOlder(workouts),
                  weekdays: weekdays,
                  tail: tail,
                  month: month,
                ),
                false => ListView.builder(
                  controller: widget.controller ?? _ownController,
                  reverse: true,
                  // clear of the active workout's button, over the current month
                  padding: const .only(bottom: 72),
                  itemCount: count + 1,
                  itemBuilder: (context, index) {
                    if (index >= count - 1) _loadOlder(workouts);
                    if (index == count) {
                      return tail();
                    }
                    return month(DateTime(newest.year, newest.month - index));
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarMonth extends StatelessWidget {
  final DateTime month;
  final Map<int, List<Workout>> days;

  /// The muscle families each day trained, busiest first (#617).
  final Map<int, List<MuscleFamily>> families;

  /// Days trained whose workouts the filter all leaves out (#610).
  final Set<int> hidden;
  final int firstWeekday;
  final String? selectedId;
  final _DayActions actions;
  final DateTime today;

  /// Whether it says its own name: not where what is around it does (#739).
  final bool titled;

  const new({
    super.key,
    this.titled = true,
    required this.month,
    required this.days,
    this.families = const {},
    this.hidden = const {},
    required this.firstWeekday,
    required this.actions,
    required this.today,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final locale = L.of(context).localeName;
    final theme = Theme.of(context);
    final offset = (month.weekday % 7 - firstWeekday + 7) % 7;
    final length = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + length) / 7).ceil();
    return Padding(
      padding: .fromLTRB(4, titled ? 16 : 0, 4, 16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (titled)
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
                    child: _CalendarDay(
                      date: date,
                      label: label,
                      sessions: days[day] ?? const [],
                      families: families[day] ?? const [],
                      filteredOut: hidden.contains(day),
                      when: switch (date.compareTo(today)) {
                        < 0 => .past,
                        0 => .today,
                        _ => .future,
                      },
                      selectedId: selectedId,
                      actions: actions,
                      child: number,
                    ),
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

/// The day of the month a workout counts on: the one it started, on the
/// user's clock — a start is UTC.
int _dayOf(Workout workout) => workout.start.toLocal().day;

/// The families a day trained, from its sets per family: the busiest first,
/// ties in [MuscleFamily] order. All of them are read out; three are drawn.
List<MuscleFamily> _ranked(Map<MuscleFamily, int> sets) {
  return sets.keys.toList()..sort(
    (one, two) => switch (sets[two]!.compareTo(sets[one]!)) {
      0 => one.index.compareTo(two.index),
      final bySets => bySets,
    },
  );
}

/// As many dots as fit under a day's number.
const _dotsADay = 3;

/// What a day can do besides show what it holds (#618), the same for every
/// day of the calendar:
/// - [open]: open one of its workouts;
/// - [log]: log a workout on it, while Past workouts is on;
/// - [askToLog]: the one ask for Past workouts, then logging, while it was
///   never asked about — offered only by an empty past day;
/// - [start]: start a workout now, while none is going — offered only today;
/// - [loadedFrom]: while older history is still to come, the first day known
///   whole. A day before it may hold workouts not fetched yet, so it never
///   offers logging as if it were empty.
typedef _DayActions = ({
  void Function(Workout)? open,
  void Function(DateTime day)? log,
  Future<void> Function(DateTime day)? askToLog,
  VoidCallback? start,
  DateTime? loadedFrom,
});

/// Where a day falls, against today.
enum _When { past, today, future }

/// What a day's list offers after its workouts.
enum _Extra { start, log }

/// One day of the calendar.
///
/// A day trained is filled, and outlined while the detail pane shows one of
/// its workouts; it is marked whether or not it opens anything. One workout
/// carries a check, several their count (#619).
///
/// Tapped (#618):
/// - one workout, and nothing else to offer: opens it;
/// - anything more — several workouts, today's start, another to log — opens
///   a short list: the workouts earliest first, then the rest;
/// - an empty past day logs a workout on it, or asks first (see [_DayActions]);
/// - a future day does nothing: planned days are #430's.
class _CalendarDay extends StatelessWidget {
  final DateTime date;

  /// The day, as read out: its full date.
  final String label;

  /// The day's workouts, newest first, as History holds them: those the
  /// filter lets through, while one is set (#610).
  final List<Workout> sessions;

  /// Whether the day holds workouts the filter all leaves out (#610).
  final bool filteredOut;

  /// The muscle families the day trained, busiest first (#617): every one
  /// read out by name after the day, the first [_dotsADay] drawn.
  final List<MuscleFamily> families;
  final _When when;

  /// The workout open in the detail pane, if any.
  final String? selectedId;
  final _DayActions actions;
  final Widget child;

  const new({
    required this.date,
    required this.label,
    required this.sessions,
    this.filteredOut = false,
    this.families = const [],
    required this.when,
    required this.actions,
    required this.child,
    this.selectedId,
  });

  /// Whether the day is known whole: false for one before the oldest page
  /// fetched so far.
  bool get _known => switch (actions.loadedFrom) {
    final DateTime from => !date.isBefore(from),
    null => true,
  };

  List<_Extra> get _extras {
    return [
      if (when == .today && actions.start != null) .start,
      if (when != .future && _known && actions.log != null) .log,
    ];
  }

  Future<void> _choose(BuildContext context, List<_Extra> extras) async {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final open = actions.open;
    // a workout is listed only where it opens: a row that does nothing is dead
    final listed = open == null ? const <Workout>[] : sessions;
    final checks = listed.any((each) => each.id == selectedId);

    Widget entry(Workout workout) {
      return Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Text(
            workout.name ?? l.defaultWorkoutName(workout.start),
            maxLines: 1,
            overflow: .ellipsis,
            style: textTheme.bodyLarge,
          ),
          Text(
            localizations.formatTimeOfDay(
              TimeOfDay.fromDateTime(workout.start.toLocal()),
              alwaysUse24HourFormat: h24,
            ),
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    // checked only while the pane shows one of them: a check column with
    // nothing in it is an empty gutter on every row; and while it is there,
    // every row takes it, so the rows line up
    PopupMenuEntry<Object> item(Object value, Widget child, {Key? key, bool checked = false}) {
      return switch (checks) {
        true => CheckedPopupMenuItem<Object>(key: key, value: value, checked: checked, child: child),
        false => PopupMenuItem<Object>(key: key, value: value, child: child),
      };
    }

    final picked = await showMenu<Object>(
      context: context,
      position: menuOver(context, context.findRenderObject()! as RenderBox),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      items: [
        for (final workout in listed.reversed) item(workout, entry(workout), checked: workout.id == selectedId),
        if (listed.isNotEmpty && extras.isNotEmpty) const PopupMenuDivider(),
        for (final extra in extras)
          item(
            extra,
            key: switch (extra) {
              .start => AppKeys.calendarStart,
              .log => AppKeys.calendarLog,
            },
            Text(switch ((extra, sessions.isEmpty)) {
              (.start, _) => l.startNewWorkout,
              (.log, true) => l.calendarLogOnDay,
              (.log, false) => l.calendarAddAnother,
            }),
          ),
      ],
    );
    switch (picked) {
      case Workout workout:
        open?.call(workout);
      case _Extra.start:
        actions.start?.call();
      case _Extra.log:
        actions.log?.call(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final day = switch (when) {
      .today => l.calendarDayToday(label),
      .past || .future => label,
    };
    final extras = _extras;
    final open = actions.open;
    // one choice of what the day says and does
    final (String spoken, VoidCallback? onTap) = switch ((sessions, extras)) {
      ([final Workout only], []) when open != null => (l.calendarDayEdit(day), () => open(only)),
      ([_, ...], _) when open != null || extras.isNotEmpty => (
        l.calendarDayWorkouts(day, sessions.length),
        () => _choose(context, extras),
      ),
      ([_, ...], _) => (l.calendarDayWorkouts(day, sessions.length), null),
      // trained, but nothing the filter lets through: plain, today too
      ([], _) when filteredOut => (day, null),
      ([], _) => switch (when) {
        .past when !_known => (day, null),
        .past => switch ((actions.log, actions.askToLog)) {
          (final log?, _) => (l.calendarDayLog(day), () => log(date)),
          (null, final ask?) => (l.calendarDayLog(day), () => ask(date)),
          (null, null) => (day, null),
        },
        .today when extras.isNotEmpty => (day, () => _choose(context, extras)),
        .today || .future => (day, null),
      },
    };

    // an empty day that does nothing is only its number: no ink, no button,
    // and nothing to build on every tick of an active workout
    if (sessions.isEmpty && onTap == null) {
      return Semantics(
        container: true,
        label: spoken,
        excludeSemantics: true,
        child: Center(child: child),
      );
    }

    final ThemeData(:textTheme, colorScheme: ColorScheme(:primary, :onPrimary, :surfaceContainerHighest)) = Theme.of(
      context,
    );
    final several = sessions.length > 1;
    final selected = sessions.any((workout) => workout.id == selectedId);

    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: spoken,
      // what the day trained, by name: its colours are not read out (#617)
      value: switch (families) {
        [] => null,
        _ => families.map((family) => family.label(l)).join(', '),
      },
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: switch (sessions) {
            [] => child,
            _ => Stack(
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
                // what it trained, by colour, under the number (#617)
                if (families.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 3,
                    child: Row(
                      mainAxisAlignment: .center,
                      spacing: 2,
                      children: [for (final family in families.take(_dotsADay)) FamilyDot(family, size: 5)],
                    ),
                  ),
                Positioned(
                  right: -2,
                  top: -2,
                  // grows with the count's text, so a large text size never
                  // clips it
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: several ? const .symmetric(horizontal: 4, vertical: 2) : .zero,
                    alignment: .center,
                    decoration: BoxDecoration(color: primary, borderRadius: const .all(.circular(9))),
                    child: switch (several) {
                      true => Text(
                        '${sessions.length}',
                        style: textTheme.labelSmall?.copyWith(color: onPrimary, fontWeight: .w700, height: 1),
                      ),
                      false => Icon(Icons.check, size: 14, color: onPrimary),
                    },
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}
