part of 'workout.dart';

class TemplateEditor extends StatelessWidget {
  const TemplateEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :colorScheme) = Theme.of(context);
    final L(:newTemplate, :save) = L.of(context);
    final templates = Templates.watch(context);
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBackgroundColor,
        title: Text(newTemplate),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: PrimaryButton.shrunk(
              backgroundColor: colorScheme.secondaryContainer,
              onPressed: () {
                Navigator.of(context).pop();
                templates.saveEditable();
              },
              child: Text(save),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: WorkoutDetail(
          exercises: templates.editable ?? [],
          onDragExercise: (_) {
            // todo
          },
          onAddSet: templates.addSet,
          onAddExercises: (exercises) async {
            for (var each in exercises) {
              await Future.delayed(
                // for different IDs
                const Duration(milliseconds: 2),
                () => templates.add(each),
              );
            }
          },
        ),
      ),
    );
  }
}
