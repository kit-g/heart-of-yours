part of 'workout.dart';

/// Layout of the workout page before a workout begins.
///
/// Allows to start a new workout
/// or choose from a set of workout templates or create new ones
class _NoActiveWorkoutLayout extends StatelessWidget {
  const _NoActiveWorkoutLayout();

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :textTheme, :colorScheme) = Theme.of(context);
    final L(:startWorkout, templates: copy, :template) = L.of(context);
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
        const NewWorkoutHeader(),
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
                      context.goToTemplateEditor();
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
                      context.goToTemplateEditor();
                    },
                    onStartWorkout: (template) {},
                  );
                },
              )
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
    ) = L.of(context);
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
        )
      ],
    );
  }
}
