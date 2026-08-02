part of 'exercises.dart';

class _MaterialExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;
  final void Function(Exercise exercise, {String? tab})? onShareExercise;
  final bool allowOptions;
  final Widget? leading;
  final String? initialTab;
  final void Function(ExerciseFilter)? onFilter;
  final void Function(Exercise)? onTapAlternative;

  const _MaterialExerciseDetailPage({
    required this.exercise,
    required this.onTapWorkout,
    required this.allowOptions,
    required this.onShareExercise,
    this.leading,
    this.initialTab,
    this.onFilter,
    this.onTapAlternative,
  });

  @override
  State<_MaterialExerciseDetailPage> createState() => _MaterialExerciseDetailPageState();
}

class _MaterialExerciseDetailPageState extends State<_MaterialExerciseDetailPage>
    with SingleTickerProviderStateMixin<_MaterialExerciseDetailPage> {
  late final List<_ExerciseSection> _sections = widget.exercise.sections.toList();
  late final TabController _controller;

  @override
  void initState() {
    super.initState();

    final initial = _initialSection(widget.exercise, widget.initialTab);
    _rememberedSection = initial;
    _controller = TabController(
      length: _sections.length,
      initialIndex: _sections.indexOf(initial),
      vsync: this,
    )..addListener(_rememberTab);
  }

  // keep the remembered tab in sync so switching to a sibling exercise (the iPad
  // master-detail) opens on the same one
  void _rememberTab() {
    if (!_controller.indexIsChanging) {
      _rememberedSection = _sections[_controller.index];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.allowOptions)
            if (widget.exercise.isMine)
              IconButton(
                tooltip: L.of(context).exerciseOptions,
                onPressed: () => _onExerciseMenu(context, widget.exercise),
                icon: const Icon(Icons.more_vert_rounded),
              ),
          if (!widget.exercise.isMine)
            IconButton(
              tooltip: L.of(context).share,
              onPressed: () => widget.onShareExercise?.call(widget.exercise, tab: _sections[_controller.index].name),
              icon: const Icon(Icons.share_outlined),
            ),
        ],
        leading: widget.leading,
        title: widget.exercise.archivedAppBarTitle(context),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: TabBar(
            controller: _controller,
            tabs: _sections.map((section) => Tab(text: _copy(context, section))).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _controller,
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
