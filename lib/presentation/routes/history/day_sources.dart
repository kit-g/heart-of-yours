part of 'history.dart';

/// Whether a workout can be made from [source], a template or a workout: one
/// with no set has nothing to make it from.
bool _fills(Iterable<WorkoutExercise> source) => source.any((exercise) => exercise.isNotEmpty);

/// One of the lifter's own templates to make a workout from (#737), as the
/// Workout tab files them: each folder's under its name, then the rest.
Future<Template?> _pickTemplate(BuildContext context) {
  final l = L.of(context);
  final templates = Templates.of(context);
  final known = {for (final folder in templates.folders) folder.id};
  final folders = [
    for (final folder in templates.folders)
      (name: folder.name as String?, templates: templates.templatesIn(folder).where(_fills).toList()),
    // one whose folder hasn't been read is with the rest, not nowhere
    (name: null, templates: templates.where(_fills).where((each) => !known.contains(each.folderId)).toList()),
  ].where((folder) => folder.templates.isNotEmpty).toList();
  return _showChoices<Template>(
    context,
    key: AppKeys.templateChoices,
    title: l.calendarFromTemplate,
    list: (context, scroll) {
      final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
      return ListView(
        controller: scroll,
        padding: const .only(bottom: 16),
        children: [
          for (final (:name, :templates) in folders) ...[
            if (name case final String name)
              Padding(
                padding: const .fromLTRB(16, 16, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(name, style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ),
              )
            else if (folders.length > 1)
              const Divider(indent: 16, endIndent: 16),
            for (final template in templates)
              _Choice(
                key: AppKeys.makeFromTemplate(template.id),
                title: template.name ?? l.defaultWorkoutName(),
                exercises: template,
                onTap: () => Navigator.of(context).pop(template),
              ),
          ],
        ],
      );
    },
  );
}

/// A workout in the lifter's history to copy into a new one (#737), newest
/// first; older ones are read as the list is scrolled to them.
Future<Workout?> _pickWorkout(BuildContext context) {
  final l = L.of(context);
  final workouts = Workouts.of(context);
  final days = DateFormat.yMMMEd(l.localeName);
  return _showChoices<Workout>(
    context,
    key: AppKeys.workoutChoices,
    title: l.calendarFromWorkout,
    list: (context, scroll) => ListenableBuilder(
      listenable: workouts,
      builder: (context, _) {
        final past = workouts.byMonth.values.expand((month) => month).where(_fills).toList();
        return ListView.builder(
          controller: scroll,
          padding: const .only(bottom: 16),
          itemCount: past.length + 1,
          itemBuilder: (context, index) {
            if (index == past.length) {
              return _OlderWorkouts(workouts: workouts);
            }
            final workout = past[index];
            return _Choice(
              key: AppKeys.makeFromWorkout(workout.id),
              title: workout.name ?? l.defaultWorkoutName(workout.start),
              day: days.format(workout.start.toLocal()),
              exercises: workout,
              onTap: () => Navigator.of(context).pop(workout),
            );
          },
        );
      },
    ),
  );
}

/// The list's end: asks for older history as it comes into view, once each
/// time there is an end to reach.
class _OlderWorkouts extends StatelessWidget {
  final Workouts workouts;

  const new({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final Workouts(:loadingMoreHistory, :historyPageError, :hasMoreHistory) = workouts;
    if (hasMoreHistory && !loadingMoreHistory && !historyPageError) {
      // after the frame: the read notifies, and the list listens
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) workouts.loadMoreHistory();
      });
    }
    return _HistoryTail(
      loading: loadingMoreHistory,
      error: historyPageError,
      hasMore: hasMoreHistory,
      onRetry: workouts.loadMoreHistory,
    );
  }
}

/// A sheet of things to pick one of, which its drag makes taller. No wider
/// than a dialog on a tablet.
Future<T?> _showChoices<T>(
  BuildContext context, {
  required Key key,
  required String title,
  required Widget Function(BuildContext context, ScrollController scroll) list,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      minChildSize: .3,
      maxChildSize: .95,
      builder: (context, scroll) => Column(
        key: key,
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .fromLTRB(16, 20, 16, 8),
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          Expanded(child: list(context, scroll)),
        ],
      ),
    ),
  );
}

/// One to pick: its name, its [day] when it was done on one, and what is in it.
class _Choice extends StatelessWidget {
  final String title;
  final String? day;
  final Iterable<WorkoutExercise> exercises;
  final VoidCallback onTap;

  const new({super.key, required this.title, this.day, required this.exercises, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final names = exercises.where((each) => each.isNotEmpty).map((each) => each.exercise.name).join(', ');
    return ListTile(
      title: Text(title, maxLines: 2, overflow: .ellipsis),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          if (day case final String day) Text(day),
          Text(names, maxLines: 2, overflow: .ellipsis),
        ],
      ),
      onTap: onTap,
    );
  }
}
