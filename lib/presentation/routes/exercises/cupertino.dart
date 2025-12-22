part of 'exercises.dart';

class _CupertinoExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;
  final bool allowOptions;

  const _CupertinoExerciseDetailPage({
    required this.exercise,
    required this.onTapWorkout,
    required this.allowOptions,
  });

  @override
  State<_CupertinoExerciseDetailPage> createState() => _CupertinoExerciseDetailPageState();
}

class _CupertinoExerciseDetailPageState extends State<_CupertinoExerciseDetailPage> {
  final _section = ValueNotifier<_ExerciseSection?>(null);
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();

    _section.value = widget.exercise.sections.first;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _section.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: widget.exercise.archivedAppBarTitle(context),
        actions: [
          if (widget.allowOptions)
          if (widget.exercise.isMine)
            IconButton(
              onPressed: () => _onExerciseMenu(context, widget.exercise),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: ValueListenableBuilder<_ExerciseSection?>(
            valueListenable: _section,
            builder: (_, section, __) {
              return CupertinoSlidingSegmentedControl<_ExerciseSection>(
                children: Map.fromEntries(
                  widget.exercise.sections.map(
                    (section) {
                      return MapEntry(section, Text(_copy(context, section)));
                    },
                  ),
                ),
                groupValue: section,
                onValueChanged: (section) {
                  _section.value = section;
                  if (section != null) {
                    _pageController.animateToPage(
                      widget.exercise.sections.toList().indexOf(section),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.ease,
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
      body: PageView(
        onPageChanged: (index) {
          _section.value = widget.exercise.sections.toList()[index];
        },
        controller: _pageController,
        children: _pages(widget.exercise, onTapWorkout: widget.onTapWorkout),
      ),
    );
  }
}
