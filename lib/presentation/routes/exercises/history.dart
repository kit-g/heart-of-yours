part of 'exercises.dart';

class _History extends StatelessWidget {
  final Exercise exercise;
  final Future<Iterable<ExerciseAct>> Function(Exercise exercise, {int? pageSize, String? anchor}) historyLookup;
  final Future<void> Function(String) onTapWorkout;

  const _History({
    required this.exercise,
    required this.historyLookup,
    required this.onTapWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = Preferences.watch(context);
    return FutureBuilder<Iterable<ExerciseAct>>(
      future: historyLookup(exercise),
      builder: (_, future) {
        final AsyncSnapshot(connectionState: state, :error, :data) = future;
        return switch ((state, error, data)) {
          (ConnectionState.waiting, _, _) => const Center(
              child: CircularProgressIndicator(),
            ),
          (_, Object _, _) => const _ErrorState(),
          (ConnectionState.done, null, Iterable<ExerciseAct> query) => Builder(
              builder: (_) {
                if (query.isEmpty) {
                  return const Column(
                    children: [
                      _EmptyState(),
                    ],
                  );
                }

                final acts = query.toList()..sort();
                return ListView.builder(
                  itemCount: acts.length,
                  itemBuilder: (_, index) {
                    final act = acts[index];
                    return _Card(
                      act: act,
                      onTapWorkout: onTapWorkout,
                      prefs: prefs,
                    );
                  },
                );
              },
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _Card extends StatelessWidget {
  final ExerciseAct act;
  final void Function(String) onTapWorkout;
  final Preferences prefs;

  const _Card({
    required this.act,
    required this.onTapWorkout,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    final ExerciseAct(:workoutName, :start) = act;
    final ThemeData(:textTheme) = Theme.of(context);
    return Card(
      shape: _shape,
      child: InkWell(
        customBorder: _shape,
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
                        DateFormat('yMMMd').format(start),
                        style: textTheme.bodySmall,
                      )
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
                      DateFormat('EEEE, h:mm a').format(start.toLocal()),
                      style: textTheme.bodySmall,
                    )
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
                          text: _formatSet(set, prefs: prefs),
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatSet(ExerciseSet set, {required Preferences prefs}) {
    switch (set.category) {
      case Category.weightedBodyWeight:
        return switch (set) {
          ExerciseSet(:double weight, :int reps) => '+${prefs.weight(weight)} x $reps',
          _ => '',
        };
      case Category.assistedBodyWeight:
        return switch (set) {
          ExerciseSet(:double weight, :int reps) => '-${prefs.weight(weight)} x $reps',
          _ => '',
        };
      case Category.repsOnly:
        return '${set.reps} x';
      case Category.machine:
      case Category.barbell:
      case Category.dumbbell:
        return switch (set) {
          ExerciseSet(:double weight, :int reps) => '${prefs.weight(weight)} x $reps',
          _ => '',
        };
      case Category.duration:
        return switch (set) {
          ExerciseSet(:int duration) => Duration(seconds: duration).formatted(),
          _ => '',
        };
      case Category.cardio:
        return switch (set) {
          ExerciseSet(:int duration, :double distance) => ''
              '${Duration(seconds: duration).formatted()}'
              ' | '
              '${_double(prefs.distanceValue(distance))}',
          _ => '',
        };
    }
  }
}
