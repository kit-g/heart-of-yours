part of 'history.dart';

class HistoryPage extends StatefulWidget {
  final VoidCallback onNewWorkout;
  final void Function(Workout)? onSaveAsTemplate;
  final void Function(Workout)? onEditWorkout;
  final void Function(Workout)? onTapWorkout;
  final void Function(Workout)? onDeleteWorkout;

  /// A day set aside with "Not today" (#312): opens its page (#391).
  final void Function(TrainingSkip)? onTapSkip;

  /// Opens the list of suspicious entries (#428). Without it, or with the
  /// feature off, History has no way there.
  final VoidCallback? onEntryReview;

  /// Logs a workout that already happened (#530), by default in the last
  /// hour, or [on] a day tapped in the calendar (#618). Without it, or with
  /// the feature off, History has no way in.
  final void Function({DateTime? on})? onLogPastWorkout;
  final VoidCallback onOpenActiveWorkout;
  final Widget? detail;
  final Future<void> Function(Iterable<Media>, {required int startingIndex, String? workoutId})? onTapImage;

  /// Id of the workout open in [detail], so the list can mark which card the
  /// pane is showing. Null in compact, where the detail covers the list anyway.
  final String? selectedId;

  const new({
    super.key,
    required this.onNewWorkout,
    required this.onSaveAsTemplate,
    required this.onEditWorkout,
    this.onTapWorkout,
    this.onDeleteWorkout,
    this.onTapSkip,
    this.onEntryReview,
    this.onLogPastWorkout,
    required this.onOpenActiveWorkout,
    this.detail,
    this.onTapImage,
    this.selectedId,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

const _imageSize = 120.0;

/// The widest a row of History's list gets (#611): a readable line, plus the
/// cards' own 16pt margins either side.
const _rowWidth = readableWidth + 32;

/// The colour key, the weekday row and one six-week month: less than this,
/// and the calendar is not worth showing beside its header.
const _calendarMinHeight = 460.0;

class _HistoryPageState extends State<HistoryPage> with AfterLayoutMixin<HistoryPage>, HasHaptic {
  late final Exercises _exercises;

  /// What workouts trained (#610, #617), kept across builds — the page
  /// rebuilds every second of an active workout — and read afresh whenever
  /// the library changes under it.
  WorkoutGroups? _trained;

  WorkoutGroups get _workoutGroups => _trained ??= WorkoutGroups(_exercises.lookup);

  void _forgetGroups() => _trained = null;

  @override
  void initState() {
    super.initState();
    _exercises = Exercises.of(context)..addListener(_forgetGroups);
  }

  @override
  void dispose() {
    _exercises.removeListener(_forgetGroups);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(scaffoldBackgroundColor: backgroundColor, :textTheme, :colorScheme, :sectionHeader) = Theme.of(
      context,
    );

    final L(:myProgression) = L.of(context);
    final workouts = Workouts.watch(context);
    final byMonth = workouts.byMonth;
    // History narrowed to some muscle groups (#610). What a workout trained is
    // read off the library, so the page hears when it loads or changes.
    final filter = HistoryFilter.watch(context);
    final exercises = Exercises.watch(context);
    final trained = _workoutGroups;
    final bool Function(Workout)? shows = switch (filter.isOn) {
      true => (workout) => filter.shows(workout, trained),
      false => null,
    };
    // How much of history the filter sees: all of it once the backfill (#113)
    // has it on the device — the server's pages say there is more on every
    // launch, so they are not the word on that. Until then, the backfill is
    // the one bringing it down; the filter never pages for itself.
    final backfill = Backfill.watch(context);
    final whole = !workouts.hasMoreHistory || backfill.isWhole;
    final (searching, stalled) = switch (whole) {
      true => (false, false),
      false => (backfill.status == .running, backfill.status == .failed),
    };
    // the days set aside: a program's while it is shown (Programs on, or a
    // coach's under Your coach, #593), a plain day's while "Not today" is
    // (#312); with all off, History is as it was
    final preferences = Preferences.watch(context);
    final programs = Programs.watch(context);
    final skips = programs.skips.where(
      (skip) => switch (skip.isDay) {
        true => preferences.isOn(.notToday),
        false => preferences.programShown(programs.programOf(skip)),
      },
    );
    // the photo strip is the whole history's, so a filter puts it away
    final images = filter.isOn ? const <WorkoutImage>[] : workouts.images;
    final layout = LayoutProvider.of(context);
    final view = preferences.historyView;
    final compact = preferences.historyDensity == .compact;
    final appBar = SliverAppBar(
      // Narrows both views to some muscle groups (#610). On the leading side,
      // which the centred title leaves free: the actions already reach the
      // title on a phone with Copy for AI and Past workouts on, and in a
      // tablet's narrow list pane.
      leading: switch (workouts.history.isNotEmpty || filter.isOn) {
        true => _FilterButton(
          filter: filter,
          trained: trained,
          // greyed only off the whole history, read with the library's tags
          whole: whole && exercises.isInitialized,
        ),
        false => null,
      },
      actions: [
        // Copy for AI (#259): a stretch of training, while it is on
        if (preferences.isOn(.copyForAi) && workouts.history.isNotEmpty)
          IconButton(
            key: AppKeys.copyForAiHistory,
            tooltip: L.of(context).copyForAi,
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => copyPeriodForAi(context),
          ),
        if (widget.onEntryReview case final VoidCallback open) _EntryReviewButton(onPressed: open),
        // a workout that already happened (#530), while it is on
        if ((widget.onLogPastWorkout, preferences.isOn(.pastWorkouts)) case (
          final void Function({DateTime? on}) log,
          true,
        ))
          IconButton(
            key: AppKeys.logPastWorkout,
            tooltip: L.of(context).logPastWorkout,
            icon: const Icon(Icons.more_time_rounded),
            onPressed: () => log(),
          ),
        // the switch between the two views (#609), remembered as the
        // view History opens on
        IconButton(
          key: AppKeys.historyViewSwitch,
          tooltip: switch (view) {
            .list => L.of(context).showAsCalendar,
            .calendar => L.of(context).showAsList,
          },
          icon: Icon(switch (view) {
            .list => Icons.calendar_month_rounded,
            .calendar => Icons.view_agenda_outlined,
          }),
          onPressed: () {
            buzz();
            Preferences.of(context).setHistoryView(switch (view) {
              .list => .calendar,
              .calendar => .list,
            });
          },
        ),
      ],
      scrolledUnderElevation: 0,
      backgroundColor: backgroundColor,
      pinned: true,
      expandedHeight: 80.0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(L.of(context).history),
        centerTitle: true,
      ),
    );
    // built only for the view on screen: the rows are a pass over all of
    // history, and Workouts notifies every second of an active workout
    Widget listview() {
      final items = switch (shows) {
        // the days set aside are no workout of any group
        final bool Function(Workout) shows => _historyRows(
          {
            for (final MapEntry(:key, :value) in byMonth.entries)
              if (value.where(shows).toList() case final shown when shown.isNotEmpty) key: shown,
          },
          const [],
          partial: workouts.hasMoreHistory,
        ),
        null => _historyRows(byMonth, skips, partial: workouts.hasMoreHistory),
      };
      return CustomScrollView(
        // keyed by view, so switching replaces the scrollable rather than
        // handing one view's offset and physics to the other
        key: const ValueKey(HistoryView.list),
        physics: const ClampingScrollPhysics(),
        controller: Scrolls.of(context).historyScrollController,
        slivers: [
          appBar,
          // the one ask for suspicious entries, once there is one (#428)
          const SliverToBoxAdapter(child: _EntryReviewOffer()),
          if (filter.isOn) SliverToBoxAdapter(child: _FilterChips(filter: filter)),
          if (images.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      myProgression.toUpperCase(),
                      style: sectionHeader,
                    ),
                  ),
                  SizedBox(
                    height: _imageSize,
                    child: ListView.builder(
                      scrollDirection: .horizontal,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        final last = index == images.length - 1;
                        final first = index == 0;
                        return GestureDetector(
                          onTap: () {
                            widget.onTapImage?.call(
                              images,
                              startingIndex: index,
                              workoutId: image.workoutId,
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.only(left: first ? 16 : 2, right: last ? 16 : 2),
                            child: SizedBox(
                              width: _imageSize,
                              child: ClipRRect(
                                borderRadius: BorderRadiusGeometry.circular(4),
                                child: AppImage(
                                  url: image.link,
                                  bytes: image.bytes,
                                  fit: .cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      itemCount: images.length,
                    ),
                  ),
                ],
              ),
            ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: switch ((filter.isOn, searching, stalled)) {
                (false, _, _) => const _EmptyState(),
                // nothing yet, and older workouts still coming down
                (true, true, _) => const _Searching(),
                // and they stopped coming: no saying there is nothing
                (true, _, true) => Center(
                  child: _HistoryTail(
                    loading: false,
                    error: true,
                    hasMore: true,
                    onRetry: () => Backfill.of(context).retry(),
                  ),
                ),
                (true, false, false) => _FilteredEmpty(onClear: filter.clear),
              },
            )
          else
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                // Build-position trigger: as the tail of the list comes into view,
                // pull the next page. Deferred a frame so it never notifies during
                // build; loadMoreHistory is a no-op when already loading or done.
                // Pauses on error so a failed page doesn't auto-retry in a loop —
                // the tail shows a manual retry instead.
                // Under a filter the list is a few rows of the whole history, its
                // tail always in sight: the backfill brings the rest, not this.
                if (!filter.isOn &&
                    workouts.hasMoreHistory &&
                    !workouts.historyPageError &&
                    index >= items.length - 3) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) {
                      if (context.mounted) Workouts.of(context).loadMoreHistory();
                    },
                  );
                }
                final item = items[index];
                // Measured and capped, every row alike (#611): a compact card's
                // three lines must not stretch into a bar across a wide pane,
                // and the rows beside it keep the same width.
                final row = switch (item) {
                  String key => _MonthHeader(monthKey: key),
                  Workout workout => WorkoutItem(
                    workout: workout,
                    onStartNewWorkout: widget.onNewWorkout,
                    onSaveAsTemplate: widget.onSaveAsTemplate,
                    onEditWorkout: widget.onEditWorkout,
                    onTap: widget.onTapWorkout,
                    onDeleteWorkout: widget.onDeleteWorkout,
                    onTapImageIcon: widget.onTapImage,
                    highlighted: workout.id == widget.selectedId,
                    compact: compact,
                    trained: trained,
                  ),
                  TrainingSkip skip => _SkipItem(skip: skip, onTap: widget.onTapSkip),
                  _ => const SizedBox.shrink(),
                };
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _rowWidth),
                    child: row,
                  ),
                );
              },
            ),
          if (items.isNotEmpty)
            SliverToBoxAdapter(
              child: switch (filter.isOn) {
                // where the filter's search stands (#610)
                true => _HistoryTail(
                  loading: searching,
                  error: stalled,
                  hasMore: !whole,
                  onRetry: () => Backfill.of(context).retry(),
                ),
                false => _HistoryTail(
                  loading: workouts.loadingMoreHistory,
                  error: workouts.historyPageError,
                  hasMore: workouts.hasMoreHistory,
                  onRetry: () => Workouts.of(context).loadMoreHistory(),
                ),
              },
            ),
        ],
      );
    }

    // The same header over the calendar (#609), whose months scroll by
    // themselves. The calendar takes what is left under the header and any
    // offer; when that is too little for a month (a small phone, large text,
    // an offer showing), it takes the screen under the collapsed bar instead,
    // and the header and offer scroll away to make room.
    Widget calendar() {
      return CustomScrollView(
        key: const ValueKey(HistoryView.calendar),
        physics: const ClampingScrollPhysics(),
        slivers: [
          appBar,
          const SliverToBoxAdapter(child: _EntryReviewOffer()),
          if (filter.isOn) SliverToBoxAdapter(child: _FilterChips(filter: filter)),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final remaining = constraints.viewportMainAxisExtent - constraints.precedingScrollExtent;
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: remaining >= _calendarMinHeight
                      ? remaining
                      : constraints.viewportMainAxisExtent - kToolbarHeight,
                  child: HistoryCalendar(
                    key: AppKeys.historyCalendar,
                    byMonth: byMonth,
                    shows: shows,
                    // coloured once the library's tags are read (#617)
                    trained: exercises.isInitialized ? trained : null,
                    onTapWorkout: widget.onTapWorkout,
                    selectedId: widget.selectedId,
                    controller: Scrolls.of(context).historyCalendarScrollController,
                    onLogOn: switch (widget.onLogPastWorkout) {
                      final void Function({DateTime? on}) log => (day) => log(on: day),
                      null => null,
                    },
                    onStartWorkout: () async {
                      final workouts = Workouts.of(context);
                      // read at the tap: the day's list may have been up while one started
                      // somewhere else — the watch, a shortcut — and that one is the way in
                      if (!workouts.hasActiveWorkout) {
                        await workouts.startWorkout(source: .blank, name: L.of(context).defaultWorkoutName());
                      }
                      if (mounted && workouts.hasActiveWorkout) widget.onNewWorkout();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    final page = switch (view) {
      .list => listview(),
      .calendar => calendar(),
    };

    return SafeArea(
      child: Scaffold(
        // the view is a stored choice: until it is read, neither one
        body: switch (workouts.historyInitialized && preferences.isInitialized) {
          false => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          true => switch (layout) {
            .compact => page,
            .wide => Row(
              children: [
                Expanded(
                  flex: 2,
                  child: page,
                ),
                const VerticalDivider(width: 1),
                // held open whether or not anything is selected, so picking a
                // workout does not resize the list underneath you
                Expanded(
                  flex: 3,
                  child: switch (widget.detail) {
                    null => const _NoSelectionState(),
                    Widget detail => detail,
                  },
                ),
              ],
            ),
          },
        },
        floatingActionButton: WorkoutTimerFloatingButton(onPressed: widget.onOpenActiveWorkout),
        floatingActionButtonLocation: .endFloat,
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    Workouts.of(context).initHistory();
  }
}

class _MonthHeader extends StatelessWidget {
  final String monthKey;

  const new({required this.monthKey});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme, :sectionHeader) = Theme.of(context);

    final date = DateTime.parse('$monthKey-01');
    final label = DateFormat.yMMMM(L.of(context).localeName).format(date);

    return Container(
      padding: const .symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label.toUpperCase(),
        style: sectionHeader,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final L(:emptyHistoryTitle, :emptyHistoryBody) = L.of(context);
    return _Placeholder(title: emptyHistoryTitle, body: emptyHistoryBody);
  }
}

/// Holds the detail pane open on a wide screen before a workout is picked.
///
/// The pane used to collapse instead, which let the list reflow from full width
/// to two fifths the moment you tapped a card.
class _NoSelectionState extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final L(:noWorkoutSelectedTitle, :noWorkoutSelectedBody) = L.of(context);
    return _Placeholder(key: AppKeys.noSelection, title: noWorkoutSelectedTitle, body: noWorkoutSelectedBody);
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final String body;

  /// The way out of the state, under its words.
  final Widget? action;

  const new({super.key, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: Column(
            mainAxisSize: .min,
            mainAxisAlignment: .center,
            spacing: 12,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall,
                textAlign: .center,
              ),
              Text(
                body,
                style: textTheme.bodyLarge,
                textAlign: .center,
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

/// The tail beneath the workout list: a page spinner while loading, a retry on
/// failure, or a quiet "you've reached the end" once everything is loaded.
class _HistoryTail extends StatelessWidget {
  final bool loading;
  final bool error;
  final bool hasMore;
  final VoidCallback onRetry;

  const new({
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final L(:historyEndReached, :historyLoadMoreError, :retry) = L.of(context);

    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    final child = switch ((loading, error, hasMore)) {
      (true, _, _) => const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      (_, true, _) => Column(
        mainAxisSize: .min,
        spacing: 4,
        children: [
          Text(historyLoadMoreError, style: muted, textAlign: .center),
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(retry),
          ),
        ],
      ),
      (_, _, false) => Text(historyEndReached, style: muted, textAlign: .center),
      _ => const SizedBox.shrink(),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(child: child),
    );
  }
}
