part of 'exercises.dart';

class _MaterialExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;

  const _MaterialExerciseDetailPage({required this.exercise});

  @override
  State<_MaterialExerciseDetailPage> createState() => _MaterialExerciseDetailPageState();
}

class _MaterialExerciseDetailPageState extends State<_MaterialExerciseDetailPage>
    with SingleTickerProviderStateMixin<_MaterialExerciseDetailPage> {
  final _section = ValueNotifier<_ExerciseSection?>(_ExerciseSection.about);
  late final _controller = TabController(length: _ExerciseSection.values.length, vsync: this);

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
                tabs: _ExerciseSection.values.map((section) => Tab(text: _copy(context, section))).toList(),
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: _pages(widget.exercise),
      ),
    );
  }
}
