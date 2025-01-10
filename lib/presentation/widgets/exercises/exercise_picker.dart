part of 'exercises.dart';

class ExercisePicker extends StatelessWidget {
  final Exercises exercises;
  final TextEditingController searchController;
  final Widget? appBar;
  final FocusNode focusNode;
  final Color? backgroundColor;
  final void Function(Exercise)? onExerciseSelected;

  const ExercisePicker({
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
}
