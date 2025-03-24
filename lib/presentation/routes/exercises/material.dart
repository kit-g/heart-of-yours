part of 'exercises.dart';

class _MaterialExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;

  const _MaterialExerciseDetailPage({
    required this.exercise,
    required this.onTapWorkout,
  });

  @override
  State<_MaterialExerciseDetailPage> createState() => _MaterialExerciseDetailPageState();
}

class _MaterialExerciseDetailPageState extends State<_MaterialExerciseDetailPage>
    with SingleTickerProviderStateMixin<_MaterialExerciseDetailPage> {
  final _section = ValueNotifier<_ExerciseSection?>(_ExerciseSection.about);
  late final TabController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TabController(length: widget.exercise.sections.length, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
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
              return TabBar(
                controller: _controller,
                tabs: widget.exercise.sections.map((section) => Tab(text: _copy(context, section))).toList(),
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: _pages(widget.exercise, onTapWorkout: widget.onTapWorkout),
      ),
    );
  }
}
