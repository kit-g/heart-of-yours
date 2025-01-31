part of 'exercises.dart';

class ExercisePicker extends StatelessWidget {
  final Exercises exercises;
  final TextEditingController searchController;
  final Widget? appBar;
  final FocusNode focusNode;
  final Color? backgroundColor;
  final void Function(Exercise)? onExerciseSelected;

  final _categoryKey = GlobalKey();
  final _targetKey = GlobalKey();

  ExercisePicker({
    super.key,
    required this.exercises,
    required this.searchController,
    required this.focusNode,
    this.appBar,
    this.backgroundColor,
    this.onExerciseSelected,
  });

  @override
  Widget build(BuildContext context) {
    final L(
      exercises: appBarTitle,
      :search,
      :pullExercise,
      :pushExercise,
      :staticExercise,
      :target,
      :category,
    ) = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      controller: Scrolls.of(context).exercisesScrollController,
      slivers: [
        if (appBar case Widget bar) bar,
        SliverPersistentHeader(
          pinned: true,
          delegate: FixedHeightHeaderDelegate(
            height: 64,
            backgroundColor: backgroundColor,
            child: SearchField(
              focusNode: focusNode,
              controller: searchController,
              hint: search,
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: FixedHeightHeaderDelegate(
            height: 44,
            backgroundColor: backgroundColor,
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: PrimaryButton.wide(
                    key: _targetKey,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          child: Icon(
                            Icons.filter_alt_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Center(
                          child: Text(
                            target,
                            style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () async {
                      return showMenu(
                        context: context,
                        position: _position(_targetKey),
                        items: <PopupMenuEntry<ExerciseFilter>>[
                          ...Target.values.map(
                            (category) {
                              return PopupMenuItem<ExerciseFilter>(
                                height: 36,
                                value: category,
                                onTap: () => exercises.addFilter(category),
                                child: Text(
                                  category.value,
                                  style: textTheme.titleSmall,
                                ),
                              );
                            },
                          )
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: PrimaryButton.wide(
                    key: _categoryKey,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          child: Icon(
                            Icons.filter_alt_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Center(
                          child: Text(
                            category,
                            style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () async {
                      return showMenu(
                        context: context,
                        position: _position(_categoryKey),
                        items: <PopupMenuEntry<ExerciseFilter>>[
                          ...Category.values.map(
                            (category) {
                              return PopupMenuItem<ExerciseFilter>(
                                height: 36,
                                value: category,
                                onTap: () => exercises.addFilter(category),
                                child: Text(
                                  category.value,
                                  style: textTheme.titleSmall,
                                ),
                              );
                            },
                          )
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        switch (exercises.isInitialized) {
          false => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          true => ValueListenableBuilder(
              valueListenable: searchController,
              builder: (__, value, _) {
                final found = exercises.search(value.text).toList();
                return SliverList.separated(
                  itemCount: found.length,
                  itemBuilder: (_, index) {
                    final exercise = found[index];
                    return _ExerciseItem(
                      exercise: exercise,
                      pushCopy: pushExercise,
                      pullCopy: pullExercise,
                      staticCopy: staticExercise,
                      onExerciseSelected: onExerciseSelected,
                      selected: exercises.hasSelected(exercise),
                    );
                  },
                  separatorBuilder: (_, index) {
                    return const Divider(
                      height: 0,
                      indent: 16,
                      endIndent: 16,
                    );
                  },
                );
              },
            ),
        }
      ],
    );
  }

  RelativeRect _position(GlobalKey key) {
    final RenderBox renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    return RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height, // Top (below the button)
      offset.dx + size.width,
      offset.dy + size.height, // Bottom (same as top for a dropdown effect)
    );
  }
}
