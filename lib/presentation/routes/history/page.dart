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
                ),
                _ => const SizedBox.shrink(),
              };
            },
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
                switch (widget.detail) {
                  null => const SizedBox.shrink(),
                  Widget detail => Expanded(
                    flex: 3,
                    child: detail,
                  ),
                },
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
    final ThemeData(:textTheme) = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: .min,
          mainAxisAlignment: .center,
          spacing: 12,
          children: [
            Text(
              emptyHistoryTitle,
              style: textTheme.headlineSmall,
              textAlign: .center,
            ),
            Text(
              emptyHistoryBody,
              style: textTheme.bodyLarge,
            ),
          ],
        ),
      ),
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
