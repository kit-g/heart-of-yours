part of 'exercises.dart';

class ExercisePicker extends StatelessWidget with HasHaptic<ExercisePicker> {
  final Exercises exercises;
  final TextEditingController searchController;
  final Widget? appBar;
  final FocusNode focusNode;
  final Color? backgroundColor;
  final void Function(Exercise, TapDownDetails?)? onExerciseSelected;

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
      :target,
      :category,
      :removeFilter,
      :mine,
    ) = L.of(
      context,
    );
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    final preferences = Preferences.watch(context);

    return CustomScrollView(
      key: AppKeys.exercisePicker,
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: PrimaryButton.wide(
                      backgroundColor: switch (exercises.targets.isEmpty) {
                        true => colorScheme.surfaceContainer,
                        false => null,
                      },
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
                          position: _targetKey.position(),
                          items: <PopupMenuEntry<ExerciseFilter>>[
                            ...Target.values.map(
                              (category) {
                                return PopupMenuItem<ExerciseFilter>(
                                  height: 36,
                                  value: category,
                                  onTap: () {
                                    buzz();
                                    exercises.addFilter(category);
                                  },
                                  child: Row(
                                    spacing: 8,
                                    children: [
                                      Text(
                                        category.icon,
                                        style: textTheme.titleLarge,
                                      ),
                                      Text(
                                        category.value,
                                        style: textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: PrimaryButton.wide(
                      backgroundColor: switch (exercises.categories.isEmpty) {
                        true => colorScheme.surfaceContainer,
                        false => null,
                      },
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
                          position: _categoryKey.position(),
                          items: <PopupMenuEntry<ExerciseFilter>>[
                            ...Category.values.map(
                              (category) {
                                return PopupMenuItem<ExerciseFilter>(
                                  height: 36,
                                  value: category,
                                  onTap: () {
                                    buzz();
                                    exercises.addFilter(category);
                                  },
                                  child: Text(
                                    category.value,
                                    style: textTheme.titleSmall,
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (exercises.hasOwn) {
                    false => const SizedBox.shrink(),
                    true => ChoiceChip(
                      selectedColor: colorScheme.tertiaryContainer,
                      label: Text(mine),
                      selected: exercises.showingMine,
                      onSelected: (v) => exercises.showingMine = v,
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
        if (exercises.filters.isNotEmpty)
          SliverPersistentHeader(
            pinned: true,
            delegate: FixedHeightHeaderDelegate(
              backgroundColor: backgroundColor,
              height: 40,
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    ...exercises.filters.indexed.map(
                      (record) {
                        final (index, filter) = record;

                        return Padding(
                          padding: EdgeInsets.only(
                            left: (index == 0) ? 8.0 : 0.0,
                            right: (index == exercises.filters.length - 1) ? 8.0 : 0.0,
                          ),
                          child: Chip(
                            deleteButtonTooltipMessage: removeFilter,
                            labelPadding: EdgeInsets.zero,
                            label: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                filter.value,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                            visualDensity: const VisualDensity(vertical: -4, horizontal: -0),
                            onDeleted: () {
                              buzz();
                              exercises.removeFilter(filter);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        switch (exercises.isInitialized) {
          false => const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          true => ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (_, value, _) {
              final mine = exercises.showingMine;
              final found = exercises.search(value.text, filters: true, isMine: mine).toList();
              return SliverList.separated(
                itemCount: found.length,
                itemBuilder: (_, index) {
                  final exercise = found[index];
                  return ExerciseItem(
                    exercise: exercise,
                    preferences: preferences,
                    onExerciseSelected: onExerciseSelected,
                    selected: exercises.hasSelected(exercise),
                  );
                },
                separatorBuilder: (_, _) {
                  return const Divider(
                    height: 0,
                    indent: 16,
                    endIndent: 16,
                  );
                },
              );
            },
          ),
        },
      ],
    );
  }
}
