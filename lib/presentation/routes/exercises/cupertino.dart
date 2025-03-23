part of 'exercises.dart';

class _CupertinoExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;

  const _CupertinoExerciseDetailPage({required this.exercise});

  @override
  State<_CupertinoExerciseDetailPage> createState() => _CupertinoExerciseDetailPageState();
}

class _CupertinoExerciseDetailPageState extends State<_CupertinoExerciseDetailPage> {
  final _section = ValueNotifier<_ExerciseSection?>(_ExerciseSection.about);
  final _pageController = PageController();

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
        automaticallyImplyLeading: false,
        title: Text(widget.exercise.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: ValueListenableBuilder<_ExerciseSection?>(
            valueListenable: _section,
            builder: (_, section, __) {
              return CupertinoSlidingSegmentedControl<_ExerciseSection>(
                children: Map.fromEntries(
                  _ExerciseSection.values.map(
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
                      _ExerciseSection.values.toList().indexOf(section),
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
          _section.value = _ExerciseSection.values.toList()[index];
        },
        controller: _pageController,
        children: _ExerciseSection.values.map(
          (s) {
            return Center(
              child: Text(_copy(context, s)),
            );
          },
        ).toList(),
      ),
    );
  }
}
