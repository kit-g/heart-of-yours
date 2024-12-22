import 'package:flutter/material.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import '../widgets/search_field.dart';

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> with AfterLayoutMixin<ExercisesPage> {
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final L(
      exercises: appBarTitle,
      :search,
      :pullExercise,
      :pushExercise,
      :staticExercise,
    ) = L.of(context);
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Consumer<Exercises>(
      builder: (context, exercises, _) {
        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              controller: exercises.scrollController,
              slivers: [
                SliverAppBar(
                  scrolledUnderElevation: 0,
                  backgroundColor: backgroundColor,
                  pinned: true,
                  expandedHeight: 100.0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(appBarTitle),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchHeaderDelegate(
                    height: 64,
                    backgroundColor: backgroundColor,
                    child: SearchField(
                      focusNode: _focusNode,
                      controller: _searchController,
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
                      valueListenable: _searchController,
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
                            );
                          },
                          separatorBuilder: (_, index) {
                            return const Divider(
                              indent: 16,
                              endIndent: 16,
                            );
                          },
                        );
                      },
                    ),
                }
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    var Exercises(:isInitialized, :init) = Exercises.of(context);
    if (!isInitialized) {
      init();
    }
  }
}

class _ExerciseItem extends StatelessWidget {
  final Exercise exercise;
  final String pushCopy;
  final String pullCopy;
  final String staticCopy;

  const _ExerciseItem({
    required this.exercise,
    required this.pushCopy,
    required this.pullCopy,
    required this.staticCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
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
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color backgroundColor;

  const _SearchHeaderDelegate({
    required this.child,
    required this.height,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
        child: SizedBox.expand(child: child),
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor;
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
