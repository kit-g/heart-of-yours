part of 'workout.dart';

class _TemplateCard extends StatelessWidget {
  final Template template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ...template.map(
            (exercise) {
              return Text(exercise.exercise.name);
            },
          )
        ],
      ),
    );
  }
}
