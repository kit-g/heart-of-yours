part of 'workout.dart';

/// Allows to start a new workout
/// or choose from a set of workout templates or create new ones
class _TemplatesLayout extends StatelessWidget {
  final void Function({bool? newTemplate}) goToTemplateEditor;
  final VoidCallback onNewWorkout;

  const _TemplatesLayout({
    required this.goToTemplateEditor,
    required this.onNewWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :textTheme, :colorScheme) = Theme.of(context);
    final L(:startWorkout, templates: copy, :template, :exampleTemplates) = L.of(context);
    final templates = Templates.watch(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          scrolledUnderElevation: 0,
          backgroundColor: scaffoldBackgroundColor,
          pinned: true,
          expandedHeight: 80.0,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
            title: Text(startWorkout),
          ),
        ),
        NewWorkoutHeader(openWorkoutSheet: onNewWorkout),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  copy,
                  style: textTheme.headlineSmall,
                ),
                if (templates.allowsNewTemplate)
                  PrimaryButton.shrunk(
                    backgroundColor: colorScheme.secondaryContainer,
                    onPressed: () {
                      goToTemplateEditor(newTemplate: true);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.add_rounded, size: 18),
                        Text(template),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            children: [
              ...templates.map(
                (template) {
                  return _TemplateCard(
                    template: template,
                    onDelete: (template) {
                      _showDeleteTemplateDialog(context, template);
                    },
                    onEdit: (template) {
                      templates.editable = template;
                      goToTemplateEditor();
                    },
                    onStartWorkout: (template) {
                      Workouts.of(context).startWorkout(template: template.toWorkout());
                    },
                    onTap: (template) {
                      _showStartWorkoutDialog(context, template);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  exampleTemplates,
                  style: textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            children: [
              ...templates.samples.map(
                (template) {
                  return _TemplateCard(
                    template: template,
                    onTap: (template) {
                      _showStartWorkoutDialog(context, template, allowsEditing: false);
                    },
                    onStartWorkout: (template) {
                      Workouts.of(context).startWorkout(template: template.toWorkout());
                    },
                    options: const [.startWorkout],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteTemplateDialog(BuildContext context, Template template) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :deleteTemplateBody,
      :deleteTemplateTitle,
      :cancel,
      :deleteThis,
      :deleted,
    ) = L.of(
      context,
    );
    return showBrandedDialog(
      context,
      title: Text(
        deleteTemplateTitle,
        textAlign: TextAlign.center,
      ),
      content: Text(
        deleteTemplateBody,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(cancel),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  deleteThis,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () async {
                final scaffold = ScaffoldMessenger.of(context);
                Navigator.of(context, rootNavigator: true).pop();
                await Templates.of(context).delete(template);
                scaffold.showSnackBar(SnackBar(content: Text(deleted)));
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showStartWorkoutDialog(BuildContext context, Template template, {allowsEditing = true}) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(:cancel, :startWorkout, :startNewWorkoutFromTemplate, :editTemplate) = L.of(context);
    return showBrandedDialog(
      context,
      title: Text(
        startNewWorkoutFromTemplate,
        textAlign: TextAlign.center,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...template.map(
                    (exercise) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${exercise.length} x ${exercise.exercise.name}',
                            style: textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            exercise.exercise.target.value,
                            style: textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      icon: Icon(
        Icons.fitness_center_rounded,
        color: colorScheme.onPrimaryContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(cancel),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            if (allowsEditing)
              PrimaryButton.wide(
                backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
                child: Center(
                  child: Text(editTemplate),
                ),
                onPressed: () {
                  Templates.of(context).editable = template;
                  Navigator.of(context, rootNavigator: true).pop();
                  goToTemplateEditor();
                },
              ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.primaryContainer,
              child: Center(
                child: Text(
                  startWorkout,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimaryContainer),
                ),
              ),
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Workouts.of(context).startWorkout(template: template.toWorkout());
                onNewWorkout();
              },
            ),
          ],
        ),
      ],
    );
  }
}
