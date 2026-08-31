part of 'exercises.dart';

class _Records extends StatefulWidget {
  final Exercise exercise;
  final Future<Map?> Function(Exercise exercise) recordsLookup;
  final Future<void> Function(String) onTapWorkout;

  const new({
    required this.exercise,
    required this.recordsLookup,
    required this.onTapWorkout,
  });

  @override
  State<_Records> createState() => _RecordsState();
}

class _RecordsState extends State<_Records> {
  /// null until the first lookup lands; then the error, or the records map —
  /// itself null when the exercise has never been performed.
  final _query = ValueNotifier<({Object? error, Map? records})?>(null);
  Workouts? _workouts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Records read the local mirror, but edits write through [Workouts] — the
    // editor a record opens sits right on top of this tab, and backing out
    // must not land on a record the edit already outdated.
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
      final records = await widget.recordsLookup(widget.exercise);
      if (!mounted) return;
      _query.value = (error: null, records: records);
    } catch (error) {
      if (!mounted) return;
      // a failed refresh keeps what the user is reading; only a failed first
      // load has nothing better to show than the error state
      if (_query.value?.records == null) {
        _query.value = (error: error, records: null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _query,
      builder: (_, query, _) {
        return switch (query) {
          null => const Center(
            child: CircularProgressIndicator(),
          ),
          (error: Object _, records: _) => const _ErrorState(),
          (error: null, records: null) => const Column(
            children: [
              _EmptyState(),
            ],
          ),
          (error: null, records: Map records) => _Content(
            exercise: widget.exercise,
            records: records,
            onTapWorkout: widget.onTapWorkout,
          ),
        };
      },
    );
  }
}

class _Content extends StatelessWidget {
  final Exercise exercise;
  final Map records;
  final Future<void> Function(String) onTapWorkout;

  const new({
    required this.exercise,
    required this.records,
    required this.onTapWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final prefs = Preferences.watch(context);
    final unit = Exercises.watch(context).unitFor(exercise.id);
    final formats = RecordFormats(l: l, prefs: prefs, unit: unit);

    final tiles = _tiles(l, formats);
    final lifetime = _lifetime(l, formats);
    final repMaxes = switch (records['repMaxes']) {
      List rows => rows.cast<Map>(),
      _ => null,
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // measured off the pane, not the window: inside the iPad two-pane
        // this tab gets a fraction of what MediaQuery reports
        LayoutBuilder(
          builder: (_, constraints) {
            // 240, not less: columnsFor only ever narrows cells, and under
            // ~170pt the uppercase labels start to ellipsize
            final columns = columnsFor(constraints.maxWidth, maxExtent: 240);
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
        if (repMaxes case final rows?) ...[
          const SizedBox(height: 16),
          _SectionTitle(l.repMaxes),
          Card(
            margin: .zero,
            child: Column(
              children: [
                for (final row in rows)
                  _RepMaxRow(
                    reps: row['reps'] as int,
                    weight: formats.weight(row['weight'] as num),
                    date: formats.date(row['at'] as String),
                    onTap: () => onTapWorkout(row['workoutId'] as String),
                  ),
              ],
            ),
          ),
        ],
        if (lifetime.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle(l.allTime),
          Card(
            margin: .zero,
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  for (final (name, value) in lifetime) _LifetimeRow(name: name, value: value),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<_RecordTile> _tiles(L l, RecordFormats formats) {
    _RecordTile? tile(
      String key,
      String label,
      String Function(Map record) value, {
      String Function(Map record)? detail,
    }) {
      return switch (records[key]) {
        Map record => _RecordTile(
          label: label,
          value: value(record),
          detail: [
            if (detail?.call(record) case final context? when context.isNotEmpty) context,
            formats.date(record['at'] as String),
          ].join(' · '),
          onTap: () => onTapWorkout(record['workoutId'] as String),
        ),
        _ => null,
      };
    }

    String setContext(Map record) {
      return switch ((record['weight'], record['reps'])) {
        (num weight, num reps) => '${formats.weight(weight)} × ${reps.toInt()}',
        (num weight, _) => formats.weight(weight),
        (_, num reps) => '× ${reps.toInt()}',
        _ => '',
      };
    }

    return [
      ?tile(
        'heaviest',
        l.maxWeight,
        (r) => formats.weight(r['weight'] as num),
        detail: (r) => switch (r['reps']) {
          num reps => '× ${reps.toInt()}',
          _ => '',
        },
      ),
      ?tile('oneRepMax', l.estimatedOneRepMax, (r) => formats.weight(r['value'] as num), detail: setContext),
      ?tile('bestVolume', l.bestSetVolume, (r) => formats.weight(r['value'] as num), detail: setContext),
      ?tile(
        'mostReps',
        l.mostReps,
        (r) => '${(r['reps'] as num).toInt()}',
        detail: (r) => switch (r['weight']) {
          num weight => formats.weight(weight),
          _ => '',
        },
      ),
      ?tile(
        'lightestAssistance',
        l.leastAssistance,
        (r) => formats.weight(r['weight'] as num),
        detail: (r) => switch (r['reps']) {
          num reps => '× ${reps.toInt()}',
          _ => '',
        },
      ),
      ?tile('longestDistance', l.maxDistance, (r) => formats.distance(r['distance'] as num)),
      ?tile('longestDuration', l.maxDuration, (r) => formats.time(r['duration'] as num)),
      ?tile('bestPace', l.bestPace, (r) => formats.pace(r['pace'] as num)),
    ];
  }

  List<(String, String)> _lifetime(L l, RecordFormats formats) {
    return [
      if (records['sessions'] case num sessions) (l.sessions, '${sessions.toInt()}'),
      if (records['totalVolume'] case num volume) (l.totalVolume, formats.weight(volume)),
      if (records['totalReps'] case num reps) (l.totalReps, '${reps.toInt()}'),
      if (records['totalDuration'] case num seconds) (l.totalTime, formats.time(seconds)),
      if (records['totalDistance'] case num distance) (l.totalDistance, formats.distance(distance)),
      if (records['firstAt'] case String at) (l.firstPerformed, formats.date(at)),
    ];
  }
}

/// One record, in the workout card's hero-stat language: the number in the
/// display face and tertiary color, a tiny uppercase label, and the set it
/// happened on underneath. Tapping opens that workout, in this stack.
class _RecordTile extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final VoidCallback onTap;

  const new({
    required this.label,
    required this.value,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme, :cardTheme) = Theme.of(context);

    return Card(
      margin: .zero,
      child: Tooltip(
        message: L.of(context).goToWorkout,
        child: InkWell(
          customBorder: cardTheme.shape,
          onTap: onTap,
          child: Padding(
            padding: const .all(12.0),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 2,
              children: [
                Text(
                  value,
                  style: textTheme.headlineMedium?.copyWith(fontSize: 22, color: colorScheme.tertiary),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                Text(
                  label.toUpperCase(),
                  style: textTheme.labelSmall,
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                Text(
                  detail,
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepMaxRow extends StatelessWidget {
  final int reps;
  final String weight;
  final String date;
  final VoidCallback onTap;

  const new({
    required this.reps,
    required this.weight,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    final l = L.of(context);

    return Tooltip(
      message: l.goToWorkout,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(l.repMaxCount(reps), style: textTheme.titleSmall),
              const Spacer(),
              Text(weight, style: textTheme.bodyLarge),
              const SizedBox(width: 12),
              Text(date, style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifetimeRow extends StatelessWidget {
  final String name;
  final String value;

  const new({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);

    return Padding(
      padding: const .symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          Text(name, style: textTheme.titleSmall),
          Text(value, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const new(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(bottom: 6),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
