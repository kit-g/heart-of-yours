part of 'history.dart';

class HistoryPage extends StatefulWidget {
  final VoidCallback onNewWorkout;
  final void Function(Workout)? onSaveAsTemplate;
  final void Function(Workout)? onEditWorkout;
  final void Function(Workout)? onTapWorkout;
  final void Function(Workout)? onDeleteWorkout;
  final VoidCallback onOpenActiveWorkout;
  final Widget? detail;
  final void Function({String? workoutId, String? imageId, String? imageLink, Uint8List? imageBytes})? onTapImage;

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
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final workouts = Workouts.watch(context);
    final history = workouts.history.toList()..sort();
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
            child: SizedBox(
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
                        workoutId: image.workoutId,
                        imageLink: image.link,
                        imageId: image.id,
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
          ),
        if (history.isEmpty)
          const SliverFillRemaining(
            child: _EmptyState(),
          )
        else
          SliverList.builder(
            itemCount: history.length,
            itemBuilder: (_, index) {
              return WorkoutItem(
                workout: history[history.length - index - 1],
                onStartNewWorkout: widget.onNewWorkout,
                onSaveAsTemplate: widget.onSaveAsTemplate,
                onEditWorkout: widget.onEditWorkout,
                onTap: widget.onTapWorkout,
                onDeleteWorkout: widget.onDeleteWorkout,
                onTapImageIcon: widget.onTapImage,
              );
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
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    Workouts.of(context).initHistory();
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            Text(
              emptyHistoryTitle,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
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
