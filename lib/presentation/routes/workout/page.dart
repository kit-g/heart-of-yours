part of 'workout.dart';

class WorkoutPage extends StatefulWidget {
  final void Function({bool? newTemplate}) goToTemplateEditor;
  final VoidCallback onOpenActiveWorkout;
  final void Function(Program) goToProgram;
  final void Function(TemplateFolder) goToNewProgram;
  final VoidCallback goToLibrary;

  const new({
    super.key,
    required this.goToTemplateEditor,
    required this.onOpenActiveWorkout,
    required this.goToProgram,
    required this.goToNewProgram,
    required this.goToLibrary,
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
          goToProgram: widget.goToProgram,
          goToNewProgram: widget.goToNewProgram,
          goToLibrary: widget.goToLibrary,
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
