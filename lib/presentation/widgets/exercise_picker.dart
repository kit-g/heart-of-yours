import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'search_field.dart';

class ExercisePicker extends StatelessWidget {
  final Exercises exercises;
  final TextEditingController searchController;
  final Widget? appBar;
  final FocusNode focusNode;
  final Color? backgroundColor;
  final void Function(Exercise)? onExerciseSelected;
  final Widget Function(Exercise)? trailingBuilder;

  const ExercisePicker({
    super.key,
    required this.exercises,
    required this.searchController,
    required this.focusNode,
    this.appBar,
    this.backgroundColor,
    this.onExerciseSelected,
    this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final L(
      exercises: appBarTitle,
      :search,
      :pullExercise,
      :pushExercise,
      :staticExercise,
    ) = L.of(context);
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      controller: exercises.scrollController,
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
        switch (exercises.isInitialized) {
          false => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          true => ValueListenableBuilder(
              valueListenable: searchController,
              builder: (context, value, _) {
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
                      trailingBuilder: trailingBuilder,
                      onExerciseSelected: onExerciseSelected,
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
}

class _ExerciseItem extends StatelessWidget {
  final Exercise exercise;
  final String pushCopy;
  final String pullCopy;
  final String staticCopy;
  final Widget Function(Exercise)? trailingBuilder;
  final void Function(Exercise)? onExerciseSelected;

  const _ExerciseItem({
    required this.exercise,
    required this.pushCopy,
    required this.pullCopy,
    required this.staticCopy,
    this.trailingBuilder,
    this.onExerciseSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: switch (onExerciseSelected) {
          void Function(Exercise) f => () => f(exercise),
          null => null,
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(exercise.name),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: _DirectionBadge(
                      direction: exercise.direction,
                      pullCopy: pullCopy,
                      pushCopy: pushCopy,
                      staticCopy: staticCopy,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    exercise.muscleGroup,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    exercise.level,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionBadge extends StatelessWidget {
  final ExerciseDirection direction;
  final String pushCopy;
  final String pullCopy;
  final String staticCopy;

  const _DirectionBadge({
    required this.direction,
    required this.pullCopy,
    required this.pushCopy,
    required this.staticCopy,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);

    return switch (direction) {
      ExerciseDirection.push => Tooltip(
          message: pushCopy,
          child: Icon(
            Icons.arrow_circle_right_outlined,
            color: colorScheme.tertiary,
            size: 20,
          ),
        ),
      ExerciseDirection.pull => Tooltip(
          message: pullCopy,
          child: Icon(
            Icons.arrow_circle_left_outlined,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
        ),
      ExerciseDirection.static => Tooltip(
          message: staticCopy,
          child: Icon(
            Icons.arrow_circle_down,
            color: colorScheme.onSurface,
            size: 20,
          ),
        ),
      ExerciseDirection.other => const SizedBox.shrink(),
    };
  }
}
