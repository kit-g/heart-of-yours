part of 'exercises.dart';

class ExercisePicker extends StatelessWidget with HasHaptic<ExercisePicker> {
  final Exercises exercises;
  final TextEditingController searchController;
  final Widget? appBar;
  final FocusNode focusNode;
  final Color? backgroundColor;
  final void Function(Exercise, TapDownDetails?)? onExerciseSelected;

  /// Name of the exercise open in the detail pane, when this list is the master
  /// half of a two-pane layout. Null everywhere the picker stands alone.
  final String? highlightedName;

  final _categoryKey = GlobalKey();
  final _targetKey = GlobalKey();

  new({
    super.key,
    required this.exercises,
    required this.searchController,
    required this.focusNode,
    this.appBar,
    this.backgroundColor,
    this.onExerciseSelected,
    this.highlightedName,
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
            child: Row(
              spacing: 4,
              children: [
                Expanded(
                  child: SearchField(
                    focusNode: focusNode,
                    controller: searchController,
                    hint: search,
                  ),
                ),
                _MovementFilterButton(exercises: exercises),
              ],
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
                          padding: .only(
                            left: (index == 0) ? 8.0 : 0.0,
                            right: (index == exercises.filters.length - 1) ? 8.0 : 0.0,
                          ),
                          child: Chip(
                            deleteButtonTooltipMessage: removeFilter,
                            labelPadding: .zero,
                            label: Padding(
                              padding: const .symmetric(horizontal: 4),
                              child: Text(
                                // category and target carry their own English;
                                // the movement filters carry identifiers and
                                // are worded by the presentation layer
                                switch (filter) {
                                  MovementFilter filter => filter.chipLabel(L.of(context)),
                                  _ => filter.value,
                                },
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
                    highlighted: exercise.name == highlightedName,
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

/// Opens the movement filter sheet from inside the search field.
///
/// Filled while any movement filter is set: the sheet is the only place those
/// filters can be reached, so the button has to say whether it is doing
/// anything without being opened.
class _MovementFilterButton extends StatelessWidget {
  final Exercises exercises;

  const new({required this.exercises});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);

    return ListenableBuilder(
      listenable: exercises,
      builder: (context, _) {
        final active = exercises.movementFilters.isNotEmpty;

        return IconButton(
          // a square tight box rather than `visualDensity`: the density only
          // trims the constraints, so the button kept whatever height the row
          // handed it and the splash came out an ellipse
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: .zero,
          iconSize: 20,
          tooltip: L.of(context).movement,
          icon: Icon(
            // sliders, not a funnel: Target and Category sit directly below
            // with `filter_alt`, and this opens a sheet rather than a menu —
            // three identical funnels read as three of the same control
            switch (active) {
              true => Icons.tune_rounded,
              false => Icons.tune_outlined,
            },
            color: switch (active) {
              true => colorScheme.primary,
              false => null,
            },
          ),
          onPressed: () => showMovementFilterSheet(context, exercises),
        );
      },
    );
  }
}
