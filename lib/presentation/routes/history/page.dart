part of 'history.dart';

class HistoryPage extends StatefulWidget {
  final VoidCallback onNewWorkout;
  final void Function(Workout)? onSaveAsTemplate;
  final void Function(Workout)? onEditWorkout;
  final void Function(Workout)? onTapWorkout;
  final void Function(Workout)? onDeleteWorkout;
  final VoidCallback onOpenActiveWorkout;
  final Widget? detail;
  final Future<void> Function(Iterable<Media>, {required int startingIndex, String? workoutId})? onTapImage;

  /// Id of the workout open in [detail], so the list can mark which card the
  /// pane is showing. Null in compact, where the detail covers the list anyway.
  final String? selectedId;

  const HistoryPage({
    super.key,
    required this.onNewWorkout,
    required this.onSaveAsTemplate,
    required this.onEditWorkout,
    this.onTapWorkout,
    this.onDeleteWorkout,
    required this.onOpenActiveWorkout,
    this.detail,
    this.onTapImage,
    this.selectedId,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

const _imageSize = 120.0;

class _HistoryPageState extends State<HistoryPage> with AfterLayoutMixin<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final ThemeData(scaffoldBackgroundColor: backgroundColor, :textTheme, :colorScheme, :header) = Theme.of(context);

    final L(:myProgression) = L.of(context);
    final workouts = Workouts.watch(context);
    final byMonth = workouts.byMonth;
    final items = byMonth.entries.expand((entry) => [entry.key, ...entry.value]).toList();
    final images = workouts.images;
    final layout = LayoutProvider.of(context);
    final listview = CustomScrollView(
      physics: const ClampingScrollPhysics(),
      controller: Scrolls.of(context).historyScrollController,
      slivers: [
        SliverAppBar(
          scrolledUnderElevation: 0,
          backgroundColor: backgroundColor,
          pinned: true,
          expandedHeight: 80.0,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(L.of(context).history),
            centerTitle: true,
          ),
        ),
        if (images.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    myProgression.toUpperCase(),
                    style: header,
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
        if (byMonth.isEmpty)
          const SliverFillRemaining(
            child: _EmptyState(),
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
              if (workouts.hasMoreHistory && !workouts.historyPageError && index >= items.length - 3) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) {
                    if (context.mounted) Workouts.of(context).loadMoreHistory();
                  },
                );
              }
              final item = items[index];
              return switch (item) {
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
                ),
                _ => const SizedBox.shrink(),
              };
            },
          ),
        if (byMonth.isNotEmpty)
          SliverToBoxAdapter(
            child: _HistoryTail(
              loading: workouts.loadingMoreHistory,
              error: workouts.historyPageError,
              hasMore: workouts.hasMoreHistory,
              onRetry: () => Workouts.of(context).loadMoreHistory(),
            ),
          ),
      ],
    );

    return SafeArea(
      child: Scaffold(
        body: switch (workouts.historyInitialized) {
          false => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          true => switch (layout) {
            .compact => listview,
            .wide => Row(
              children: [
                Expanded(
                  flex: 2,
                  child: listview,
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

  const _MonthHeader({required this.monthKey});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme, :header) = Theme.of(context);

    final date = DateTime.parse('$monthKey-01');
    final label = DateFormat.yMMMM().format(date);

    return Container(
      padding: const .symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label.toUpperCase(),
        style: header,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
  const _NoSelectionState();

  @override
  Widget build(BuildContext context) {
    final L(:noWorkoutSelectedTitle, :noWorkoutSelectedBody) = L.of(context);
    return _Placeholder(key: AppKeys.noSelection, title: noWorkoutSelectedTitle, body: noWorkoutSelectedBody);
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final String body;

  const _Placeholder({super.key, required this.title, required this.body});

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

  const _HistoryTail({
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

extension on ThemeData {
  TextStyle? get header {
    return textTheme.labelLarge?.copyWith(
      color: colorScheme.primary,
      fontWeight: .bold,
    );
  }
}
