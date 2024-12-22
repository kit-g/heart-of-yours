import 'package:flutter/material.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

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
    final L(exercises: appBarTitle) = L.of(context);
    return Consumer<Exercises>(
      builder: (context, exercises, _) {
        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              controller: exercises.scrollController,
              slivers: [
                SliverAppBar(
                  scrolledUnderElevation: 0,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    child: _SearchField(
                      focusNode: _focusNode,
                      controller: _searchController,
                      onClear: _searchController.clear,
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
                            return _ExerciseItem(exercise: exercise);
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

  const _ExerciseItem({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name),
          Text(exercise.muscleGroup),
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

class _SearchField extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final VoidCallback onClear;

  const _SearchField({
    required this.focusNode,
    required this.controller,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            filled: true,
            hintText: 'Search',
            suffixIcon: switch (focusNode.hasFocus) {
              true => GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded),
                ),
              false => null,
            },
          ),
        );
      },
    );
  }
}
