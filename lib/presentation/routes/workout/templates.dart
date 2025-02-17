part of 'workout.dart';

/// Layout of the workout page before a workout begins.
///
/// Allows to start a new workout
/// or choose from a set of workout templates or create new ones
class _NoActiveWorkoutLayout extends StatelessWidget {
  const _NoActiveWorkoutLayout();

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :textTheme) = Theme.of(context);
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
                PrimaryButton.shrunk(
                  onPressed: () {
                    context.goToTemplateEditor();
                  },
                  child: Text('+ $template'),
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
                  return _TemplateCard(template: template);
                },
              )
            ],
          ),
        ),
      ],
    );
  }
}
