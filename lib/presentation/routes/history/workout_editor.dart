part of 'history.dart';

class WorkoutEditor extends StatefulWidget {
  final Workout workout;

  const WorkoutEditor({super.key, required this.workout});

  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
