part of 'workout.dart';

class WorkoutPage extends StatefulWidget {
  final void Function({bool? newTemplate}) goToTemplateEditor;
  final VoidCallback onOpenActiveWorkout;

  const WorkoutPage({
    super.key,
    required this.goToTemplateEditor,
    required this.onOpenActiveWorkout,
  });

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with AfterLayoutMixin {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: _TemplatesLayout(
          goToTemplateEditor: widget.goToTemplateEditor,
          onNewWorkout: widget.onOpenActiveWorkout,
        ),
        floatingActionButton: WorkoutTimerFloatingButton(onPressed: widget.onOpenActiveWorkout),
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    Workouts.of(context).notifyOfActiveWorkout();
  }
}
