part of 'exercises.dart';

class _History extends StatefulWidget {
  final Exercise exercise;
  final Future<Iterable<ExerciseAct>> Function(Exercise exercise, {int? pageSize, String? anchor}) historyLookup;
  final Future<void> Function(String) onTapWorkout;

  const new({
    required this.exercise,
    required this.historyLookup,
    required this.onTapWorkout,
  });

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  /// null until the first lookup lands; then either the error or the sorted
  /// acts. Kept in a notifier so a refetch swaps the list in place.
  final _query = ValueNotifier<(Object?, List<ExerciseAct>?)?>(null);
  Workouts? _workouts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The lookup reads the local mirror, but edits write through [Workouts] —
    // the editor this list opens sits right on top of it, and backing out
    // must not land on a card the edit already outdated. So every [Workouts]
    // notification re-runs the query.
    final workouts = Workouts.of(context);
    if (!identical(_workouts, workouts)) {
      _workouts?.removeListener(_refetch);
      _workouts = workouts..addListener(_refetch);
      _refetch();
    }
  }

  @override
  void dispose() {
    _workouts?.removeListener(_refetch);
    _query.dispose();

    super.dispose();
  }

  Future<void> _refetch() async {
    try {
      final acts = await widget.historyLookup(widget.exercise);
      if (!mounted) return;
      _query.value = (null, acts.toList()..sort());
    } catch (error) {
      if (!mounted) return;
      // a failed *refresh* keeps the list the user is reading; only a failed
      // first load has nothing better to show than the error state
      if (_query.value?.$2 == null) {
        _query.value = (error, null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = Preferences.watch(context);
    final unit = Exercises.watch(context).unitFor(widget.exercise.id);

    return ValueListenableBuilder(
      valueListenable: _query,
      builder: (_, query, _) {
        return switch (query) {
          null || (null, null) => const Center(
            child: CircularProgressIndicator(),
          ),
          (Object _, _) => const _ErrorState(),
          (null, List<ExerciseAct> acts) when acts.isEmpty => const Column(
            children: [
              _EmptyState(),
            ],
          ),
          (null, List<ExerciseAct> acts) => ListView.builder(
            itemCount: acts.length,
            itemBuilder: (_, index) {
              final act = acts[index];
              return _Card(
                act: act,
                onTapWorkout: widget.onTapWorkout,
                prefs: prefs,
                unit: unit,
              );
            },
          ),
        };
      },
    );
  }
}

class _Card extends StatelessWidget {
  final ExerciseAct act;
  final void Function(String) onTapWorkout;
  final Preferences prefs;
  final MeasurementUnit? unit;

  const new({
    required this.act,
    required this.onTapWorkout,
    required this.prefs,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final ExerciseAct(:workoutName, :start) = act;
    final ThemeData(:textTheme, :cardTheme) = Theme.of(context);
    // no shape override: the theme's card shape carries the border that keeps
    // a white card visible on the white ground
    return Card(
      child: InkWell(
        customBorder: cardTheme.shape,
        onTap: () => onTapWorkout(act.workoutId),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (workoutName != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      workoutName,
                      style: textTheme.titleMedium,
                    ),
                    if (start != null)
                      Text(
                        DateFormat.yMMMd(L.of(context).localeName).format(start),
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    L.of(context).sets,
                    style: textTheme.titleSmall,
                  ),
                  if (start != null)
                    Text(
                      DateFormat('EEEE, h:mm a', L.of(context).localeName).format(start.toLocal()),
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
              ...act.indexed.map(
                (order) {
                  final (index, set) = order;
                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: '${index + 1}.', style: textTheme.titleSmall),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: _formatSet(set, prefs: prefs, unit: unit),
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSet(ExerciseSet set, {required Preferences prefs, MeasurementUnit? unit}) {
    switch (set.category) {
      case .weightedBodyWeight:
        return switch (set) {
          ExerciseSet(:double weight, :int reps) => '+${prefs.weight(weight, unit: unit)} x $reps',
          _ => '',
        };
      case .assistedBodyWeight:
        return switch (set) {
          ExerciseSet(:double weight, :int reps) => '-${prefs.weight(weight, unit: unit)} x $reps',
          _ => '',
        };
      case .repsOnly:
        return '${set.reps} x';
      case .machine:
      case .barbell:
      case .dumbbell:
        return switch (set) {
          ExerciseSet(:double weight, :int reps) => '${prefs.weight(weight, unit: unit)} x $reps',
          _ => '',
        };
      case .duration:
        return switch (set) {
          ExerciseSet(:int duration) => Duration(seconds: duration).formatted(),
          _ => '',
        };
      case .cardio:
        return switch (set) {
          ExerciseSet(:int duration, :double distance) =>
            ''
                '${Duration(seconds: duration).formatted()}'
                ' | '
                '${prefs.distance(distance, unit: unit)}',
          _ => '',
        };
    }
  }
}
