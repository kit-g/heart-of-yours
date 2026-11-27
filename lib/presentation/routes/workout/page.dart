part of 'workout.dart';

class WorkoutPage extends StatefulWidget {
  final void Function({bool? newTemplate}) goToTemplateEditor;
  final VoidCallback onOpenActiveWorkout;
  final void Function(Program) goToProgram;
  final void Function(TemplateFolder) goToNewProgram;
  final VoidCallback goToLibrary;

  /// Logs a workout that already happened (#530); offered while it is on.
  final VoidCallback? onLogPastWorkout;

  const new({
    super.key,
    required this.goToTemplateEditor,
    required this.onOpenActiveWorkout,
    required this.goToProgram,
    required this.goToNewProgram,
    required this.goToLibrary,
    this.onLogPastWorkout,
  });

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with AfterLayoutMixin {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        // Pulled to read the server's templates and folders again: ones an
        // assistant or another device made show without a relaunch (#448).
        // Absent without an account, which has no server to read.
        body: _Pullable(
          onRefresh: switch (Auth.watch(context).isAnonymous) {
            true => null,
            false => Templates.of(context).refresh,
          },
          child: _TemplatesLayout(
            goToTemplateEditor: widget.goToTemplateEditor,
            onNewWorkout: widget.onOpenActiveWorkout,
            goToProgram: widget.goToProgram,
            goToNewProgram: widget.goToNewProgram,
            goToLibrary: widget.goToLibrary,
            onLogPastWorkout: widget.onLogPastWorkout,
          ),
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
