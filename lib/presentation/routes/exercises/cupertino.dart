part of 'exercises.dart';

class _CupertinoExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;
  final void Function(Exercise exercise, {String? tab})? onShareExercise;
  final bool allowOptions;
  final Widget? leading;
  final String? initialTab;
  final void Function(ExerciseFilter)? onFilter;
  final void Function(Exercise)? onTapAlternative;

  const new({
    required this.exercise,
    required this.onTapWorkout,
    required this.allowOptions,
    this.onShareExercise,
    this.leading,
    this.initialTab,
    this.onFilter,
    this.onTapAlternative,
  });

  @override
  State<_CupertinoExerciseDetailPage> createState() => _CupertinoExerciseDetailPageState();
}

class _CupertinoExerciseDetailPageState extends State<_CupertinoExerciseDetailPage> {
  late final List<_ExerciseSection> _sections = widget.exercise.sections.toList();
  final _section = ValueNotifier<_ExerciseSection?>(null);
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    final initial = _initialSection(widget.exercise, widget.initialTab);
    _section.value = initial;
    _rememberedSection = initial;
    _pageController = PageController(initialPage: _sections.indexOf(initial));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _section.dispose();
    super.dispose();
  }

  void _select(_ExerciseSection? section) {
    _section.value = section;
    if (section != null) {
      _rememberedSection = section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: widget.exercise.archivedAppBarTitle(context),
        leading: widget.leading,
        actions: [
          if (widget.allowOptions) ...[
            if (widget.exercise.isMine)
              IconButton(
                tooltip: L.of(context).exerciseOptions,
                onPressed: () => _onExerciseMenu(context, widget.exercise),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            if (!widget.exercise.isMine)
              IconButton(
                tooltip: L.of(context).share,
                onPressed: () => widget.onShareExercise?.call(widget.exercise, tab: _section.value?.name),
                icon: const Icon(Icons.ios_share_rounded),
              ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: ValueListenableBuilder<_ExerciseSection?>(
            valueListenable: _section,
            builder: (_, section, _) {
              return CupertinoSlidingSegmentedControl<_ExerciseSection>(
                children: Map.fromEntries(
                  _sections.map(
                    (section) {
                      return MapEntry(section, Text(_copy(context, section)));
                    },
                  ),
                ),
                thumbColor: colorScheme.surface,
                backgroundColor: colorScheme.surfaceContainerHighest,
                groupValue: section,
                onValueChanged: (section) {
                  _select(section);
                  if (section != null) {
                    _pageController.animateToPage(
                      _sections.indexOf(section),
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
        onPageChanged: (index) => _select(_sections[index]),
        controller: _pageController,
        children: _pages(
          widget.exercise,
          onTapWorkout: widget.onTapWorkout,
          onFilter: widget.onFilter,
          onTapAlternative: widget.onTapAlternative,
        ),
      ),
    );
  }
}
