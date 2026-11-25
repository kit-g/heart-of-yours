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

  /// Whether the last few exercises done sit above the list before any typing.
  /// For picking an exercise — into a workout, a goal, a chart — where the one
  /// you want is usually one you just did. Not for the Exercises tab: that is
  /// the library, and it keeps its own order. Typing ranks by what was done
  /// last either way.
  final bool showsRecent;

  /// Why an exercise cannot answer the question, when only some can: those
  /// stay in the list, greyed, and a tap says why. Null for one that can.
  final String? Function(Exercise)? refuses;

  /// Exercises offered above the rest, before any typing: the replacements
  /// for an exercise on the sheet (#354). Typing searches the whole library,
  /// as ever.
  final List<Exercise> suggested;

  /// Creates an exercise named after a search that found nothing (#529). Null
  /// where a new exercise could not answer, and the offer is left out.
  final void Function(String name)? onCreateExercise;

  new({
    super.key,
    required this.exercises,
    required this.searchController,
    required this.focusNode,
    this.appBar,
    this.backgroundColor,
    this.onExerciseSelected,
    this.highlightedName,
    this.showsRecent = true,
    this.refuses,
    this.suggested = const [],
    this.onCreateExercise,
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
    // once for the list, not once a row (#593)
    final goEasy = goEasyOn(context);
    final previous = PreviousExercises.watch(context);
    final filters = _Filters.of(preferences.pickerGrouping, askedFor: exercises.filtersAskedFor);
    final motion = lessMotion(context) ? Duration.zero : const Duration(milliseconds: 200);

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
                if (filters.buttons) _MovementFilterButton(exercises: exercises),
              ],
            ),
          ),
        ),
        // without the filter buttons and nothing of the user's own, the row
        // would hold nothing
        if (filters.buttons || exercises.hasOwn)
          SliverPersistentHeader(
            pinned: true,
            delegate: FixedHeightHeaderDelegate(
              height: 44,
              backgroundColor: backgroundColor,
              child: AnimatedSwitcher(
                duration: motion,
                // the default stack loosens the header's tight box, and the
                // buttons shrank to their content's height inside it; the row
                // on its way out is only a picture of what was there
                layoutBuilder: (current, previous) => Stack(
                  fit: .expand,
                  children: [
                    for (final each in previous) IgnorePointer(child: ExcludeSemantics(child: each)),
                    ?current,
                  ],
                ),
                child: Row(
                  key: ValueKey(filters.buttons),
                  spacing: 8,
                  children: [
                    if (filters.buttons) ...[
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          // anchored on its own context, not a GlobalKey: the
                          // row switcher can hold two of these rows at once
                          child: Builder(
                            builder: (anchor) => PrimaryButton.wide(
                              backgroundColor: switch (exercises.targets.isEmpty) {
                                true => colorScheme.surfaceContainer,
                                false => null,
                              },
                              // a Row, not a Stack with a left-pinned icon: a wide
                              // label (ru «Категория») slid under the icon.
                              child: _FilterLabel(
                                label: target,
                                // an active filter sits on the accent fill,
                                // where the muted grey blends away
                                color: switch (exercises.targets.isEmpty) {
                                  true => colorScheme.onSurfaceVariant,
                                  false => colorScheme.onTertiaryContainer,
                                },
                              ),
                              onPressed: () async {
                                return showMenu(
                                  context: context,
                                  position: anchor.menuPosition(),
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
                                                category.label(L.of(context)),
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
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Builder(
                            builder: (anchor) => PrimaryButton.wide(
                              backgroundColor: switch (exercises.categories.isEmpty) {
                                true => colorScheme.surfaceContainer,
                                false => null,
                              },
                              // same shape as the target button above
                              child: _FilterLabel(
                                label: category,
                                color: switch (exercises.categories.isEmpty) {
                                  true => colorScheme.onSurfaceVariant,
                                  false => colorScheme.onTertiaryContainer,
                                },
                              ),
                              onPressed: () async {
                                return showMenu(
                                  context: context,
                                  position: anchor.menuPosition(),
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
                                            category.label(L.of(context)),
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
                      ),
                    ],
                    // in the row only when there is something of the user's to
                    // show: an empty slot here still took the row's 8pt gap and
                    // pushed Target and Category off-centre (#488)
                    if (exercises.hasOwn)
                      ChoiceChip(
                        selectedColor: colorScheme.tertiaryContainer,
                        // the tick is a second foreground on that fill, with its
                        // own colour slot the chip theme leaves unset — so it
                        // stayed dark while the label went light
                        checkmarkColor: colorScheme.onTertiaryContainer,
                        // The accent fill needs the accent's own ink. The chip
                        // theme sets no label style at all, so a selected chip
                        // keeps the unselected one and reads as dark text on the
                        // accent — while the two filter buttons beside it switch
                        // to onTertiaryContainer for exactly this reason.
                        //
                        // Set here rather than on the theme because the three
                        // selectable chips in the app do not agree on a selected
                        // fill: this one overrides to the accent, while the
                        // movement sheet's and the new-exercise dialog's take
                        // Material's secondaryContainer. One label colour across
                        // all of them would be wrong for two.
                        labelStyle: switch (exercises.showingMine) {
                          true => textTheme.labelLarge?.copyWith(color: colorScheme.onTertiaryContainer),
                          false => null,
                        },
                        label: Text(mine),
                        selected: exercises.showingMine,
                        onSelected: (v) => exercises.showingMine = v,
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (filters.applied && exercises.filters.isNotEmpty)
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
                          child: RemovableChip(
                            // a target that is a muscle group wears its family's
                            // colour, as History's chips do (#617)
                            avatar: switch (filter) {
                              Target(:final MuscleGroupKey muscleGroup) => Center(
                                child: FamilyDot(MuscleFamily.of(muscleGroup)),
                              ),
                              _ => null,
                            },
                            // every filter carries an identifier; the
                            // presentation layer words them
                            label: switch (filter) {
                              MovementFilter filter => filter.chipLabel(L.of(context)),
                              Category category => category.label(L.of(context)),
                              Target target => target.label(L.of(context)),
                              _ => filter.value,
                            },
                            onDeleted: () => exercises.removeFilter(filter),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        // without the library, the user's own exercises are listed under a
        // line that says so and tries again (#723)
        if (exercises case Exercises(isInitialized: false, libraryUnavailable: true))
          SliverToBoxAdapter(child: _LibraryUnavailable(retrying: exercises.retryingLibrary)),
        switch (exercises) {
          Exercises(isInitialized: false, libraryUnavailable: false) => const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          _ => ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (_, value, _) {
              final mine = exercises.showingMine;
              // Typing ranks what it finds by how well it matched, then by
              // what was done last (#135). Before any typing, a picker shows
              // the last few done above the whole library, which keeps its
              // own order ([showsRecent]); the library tab shows just that.
              final searching = value.text.trim().isNotEmpty;
              final recent = showsRecent && !searching
                  ? exercises.recent(previous.lastDone, filters: filters.applied, isMine: mine)
                  : const <Exercise>[];
              final suggestions = switch (searching) {
                true => const <Exercise>[],
                false => suggested,
              };
              final found = exercises.search(
                value.text,
                filters: filters.applied,
                isMine: mine,
                lastDone: searching ? previous.lastDone : null,
              );
              // searching ranks one list by match, whatever the grouping
              final grouping = searching ? PickerGrouping.none : preferences.pickerGrouping;
              // grouped here, outside the fold's builder: a fold changes which
              // groups are open, not what is in them
              final groups = groupExercises(found, grouping, patterns: () => exercises.patterns);
              // and pictured here, once a build rather than once a fold
              final pictures = {
                for (final (:group, exercises: members) in groups)
                  group: representativeOf(members, timesDone: previous.timesDone),
              };

              SliverList list(List<Exercise> exercises) {
                return SliverList.separated(
                  itemCount: exercises.length,
                  itemBuilder: (_, index) {
                    final exercise = exercises[index];
                    return ExerciseItem(
                      exercise: exercise,
                      preferences: preferences,
                      goEasy: goEasy,
                      onExerciseSelected: onExerciseSelected,
                      selected: this.exercises.hasSelected(exercise),
                      highlighted: exercise.id == highlightedName,
                      refusal: refuses?.call(exercise),
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
              }

              return _GroupingTransition(
                grouping: grouping,
                child: SliverMainAxisGroup(
                  slivers: [
                    if (suggestions.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _SectionHeader(L.of(context).pickerSuggested)),
                      list(suggestions),
                    ],
                    if (recent.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _SectionHeader(L.of(context).pickerRecent)),
                      list(recent),
                    ],
                    if (suggestions.isNotEmpty || recent.isNotEmpty)
                      SliverToBoxAdapter(child: _SectionHeader(L.of(context).pickerAllExercises)),
                    switch (grouping) {
                      .none => list(found),
                      .category || .target || .movement => ValueListenableBuilder<Set<String>>(
                        // its own listenable: a fold rebuilds this list, not
                        // everything that watches the preferences
                        valueListenable: preferences.openPickerGroups,
                        builder: (_, open, _) => SliverMainAxisGroup(
                          slivers: [
                            for (final (:group, exercises: members) in groups)
                              _ExerciseGroupSliver(
                                key: ValueKey(group.id),
                                group: group,
                                count: members.length,
                                open: open.contains(group.id),
                                picture: pictures[group],
                                backgroundColor: backgroundColor,
                                list: list(members),
                              ),
                          ],
                        ),
                      ),
                    },
                    if (onCreateExercise case final create? when searching && found.isEmpty)
                      SliverToBoxAdapter(
                        child: _CreateExercise(name: value.text.trim(), onCreate: create),
                      ),
                  ],
                ),
              );
            },
          ),
        },
      ],
    );
  }
}

/// A filter button's contents: the funnel, the label, and a trailing spacer
/// that mirrors the funnel so the label reads as centred on the button.
///
/// The spacer is symmetry, not information, so it is the first thing given up
/// when the label needs the room: ru «Категория» and es «Categoría» spent 48pt
/// of a half-width button on the icon and its mirror and ellipsised into
/// «Категор…». Measured rather than guessed at a breakpoint — the button is
/// half of whatever pane it is in, which on a two-pane iPad is not a fraction
/// of the window (see CLAUDE.md).
class _FilterLabel extends StatelessWidget {
  final String label;
  final Color color;

  const new({required this.label, required this.color});

  /// Matches the [Icon] beside it; [IconTheme]'s default size.
  static const _icon = 24.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(color: color);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final room = constraints.maxWidth - _icon;

        return Row(
          children: [
            Icon(Icons.filter_alt_rounded, color: color),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: style,
                ),
              ),
            ),
            if (painter.width <= room - _icon) const SizedBox(width: _icon),
          ],
        );
      },
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

/// A section's name over its part of the list, in the History month headers'
/// face.
class _SectionHeader extends StatelessWidget {
  final String label;

  const new(this.label);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const .fromLTRB(16, 16, 16, 8),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).sectionHeader,
        ),
      ),
    );
  }
}

/// Above the list when the library couldn't be downloaded (#723): what is
/// missing, and a way to try again; while that runs, a spinner in its place.
class _LibraryUnavailable extends StatelessWidget {
  final bool retrying;

  const new({required this.retrying});

  @override
  Widget build(BuildContext context) {
    final L(:exerciseLibraryUnavailable, :retry) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Padding(
      key: AppKeys.libraryUnavailable,
      padding: const .fromLTRB(16, 12, 16, 12),
      // the button under the words, which keep the width at any text size
      child: Row(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          Icon(Icons.cloud_off_rounded, size: 20, color: colorScheme.onSurfaceVariant),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 8,
              children: [
                Text(
                  exerciseLibraryUnavailable,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                switch (retrying) {
                  true => const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  false => QuietButton(
                    onPressed: () => Exercises.of(context).retryLibrary(),
                    child: Text(retry),
                  ),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The way out of a search that found nothing: an exercise of the user's own
/// by that name, through the new-exercise dialog with the name filled in
/// (#529).
class _CreateExercise extends StatelessWidget {
  final String name;
  final void Function(String name) onCreate;

  const new({required this.name, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final L(:pickerCreateExercise, :pickerCreateExerciseHint) = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);

    return ListTile(
      key: AppKeys.pickerCreateExercise,
      leading: Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary),
      title: Text(
        pickerCreateExercise(name),
        maxLines: 2,
        overflow: .ellipsis,
      ),
      subtitle: Text(pickerCreateExerciseHint),
      onTap: () => onCreate(name),
    );
  }
}

/// What of the filters a picker shows and applies (#711). Grouping already
/// sorts the library by category, target or movement, so the picker's own
/// filters beside it would only be noise: while grouped they are neither
/// shown nor applied, and kept as they were for the way back. The grouping
/// chosen decides, typing or not, so the row above the search results does
/// not come and go with each word. Mine is not one of them.
///
/// A filter the user asked for by name is ([Exercises.filtersAskedFor]): the
/// library opened "showing only" something stays showing only that, grouped,
/// with its chip in view to clear it.
enum _Filters {
  /// The buttons, the chips, and the list under them.
  editable,

  /// The chips and the list under them, and no buttons to add to them.
  askedFor,

  /// Nothing: set aside while grouped.
  setAside,
  ;

  static _Filters of(PickerGrouping grouping, {required bool askedFor}) {
    return switch ((grouping, askedFor)) {
      (.none, _) => editable,
      (.category || .target || .movement, true) => _Filters.askedFor,
      (.category || .target || .movement, false) => setAside,
    };
  }

  /// Whether the filter buttons show, to add to the filters.
  bool get buttons => this == editable;

  /// Whether the filters in force narrow the list, and their chips show.
  bool get applied => this != setAside;
}
