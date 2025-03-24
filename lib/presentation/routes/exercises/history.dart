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
                  return const _EmptyState();
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
                          text: _formatSet(
                            set,
                            distanceUnit: prefs.distanceUnit,
                            weightUnit: prefs.weightUnit,
                          ),
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

  String _formatSet(ExerciseSet set, {required MeasurementUnit distanceUnit, required MeasurementUnit weightUnit}) {
    switch (set.category) {
      case Category.weightedBodyWeight:
      case Category.assistedBodyWeight:
      case Category.repsOnly:
      case Category.dumbbell:
      case Category.barbell:
      case Category.machine:
        return '${set.reps}x';
      case Category.duration:
        return switch (set) {
          ExerciseSet(:int duration) => Duration(seconds: duration).formatted(),
          _ => '',
        };
      case Category.cardio:
        String dist(double distance) {
          return switch (distanceUnit) {
            MeasurementUnit.imperial => distance.asMiles.toStringAsFixed(2),
            MeasurementUnit.metric => distance.toString(),
          };
        }
        return switch (set) {
          ExerciseSet(:int duration, :double distance) => ''
              '${Duration(seconds: duration).formatted()}'
              ' | '
              '${dist(distance)}',
          _ => '',
        };
    }
  }
}

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

extension on Duration {
  String formatted() {
    final minutes = _pad(inMinutes.remainder(60));
    final seconds = _pad(inSeconds.remainder(60));
    return switch (inHours) {
      > 0 => '${_pad(inHours)}:$minutes:$seconds',
      _ => '$minutes:$seconds',
    };
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final L(emptyExerciseHistoryTitle: title, emptyExerciseHistoryBody: body) = L.of(context);
    return _OddState(title: title, body: body);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    final L(errorExerciseHistoryTitle: title, errorExerciseHistoryBody: body) = L.of(context);
    return _OddState(title: title, body: body);
  }
}

class _OddState extends StatelessWidget {
  final String title;
  final String body;

  const _OddState({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        spacing: 32,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          Text(
            body,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
