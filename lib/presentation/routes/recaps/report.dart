part of 'recaps.dart';

/// How many of each ranked list a month shows: the top of it is the story;
/// the tail is the whole log again.
const _ranked = 5;

/// What one month of training added up to (#154): the totals, the weeks, the
/// records it set, and the muscles, patterns and exercises it was made of.
class MonthlyReportPage extends StatefulWidget {
  /// The month's first day.
  final DateTime month;

  const new({super.key, required this.month});

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  late final Future<Recap> _recap = () {
    final preferences = Preferences.of(context);
    return Stats.of(context).getRecap(
      RecapPeriod.month(widget.month),
      firstWeekday: preferences.firstWeekday,
      weightUnit: preferences.weightUnit,
    );
  }();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Scaffold(
      key: AppKeys.monthlyReport,
      appBar: AppBar(title: Text(monthTitle(l, widget.month))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, readableWidth);
          return Align(
            alignment: .topCenter,
            child: SizedBox(
              // the page's own measure: on a tablet's pane a row of numbers
              // and the name it belongs to drift apart past it
              width: width,
              child: FutureBuilder<Recap>(
                future: _recap,
                builder: (context, snapshot) {
                  return switch (snapshot.data) {
                    null => const Center(child: CircularProgressIndicator()),
                    final recap when recap.isEmpty => Padding(
                      padding: const .all(16),
                      child: Text(l.recapNothing),
                    ),
                    final recap => _Report(recap: recap, width: width),
                  };
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Report extends StatelessWidget {
  final Recap recap;
  final double width;

  const new({required this.recap, required this.width});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final exercises = Exercises.of(context);
    final records = beatenRecords(recap).toList();
    final preferences = Preferences.of(context);
    final muscles = [
      for (final MapEntry(:key, value: count) in recap.muscles.entries)
        if (MuscleGroup.tryFromString(key.value) case final MuscleGroup group) (group.label(l), count.sets),
    ];

    return ListView(
      padding: const .fromLTRB(16, 8, 16, 32),
      children: [
        _Totals(recap: recap, width: width - 32),
        const SizedBox(height: 16),
        _Weeks(weeks: recap.weeks),
        if (records.isNotEmpty) ...[
          _Heading(l.records),
          for (final record in records)
            if (_kindOf(record) case final RecordKind kind)
              _Line(
                title: exercises.lookup(record.exerciseId)?.name ?? record.exerciseId,
                subtitle: recordKindLabel(context, kind),
                // the exercise's own unit, as its records tab shows it
                value: RecordFormats(
                  l: l,
                  prefs: preferences,
                  unit: exercises.unitFor(record.exerciseId),
                  category: record.category,
                ).value(kind, record.value),
              ),
        ],
        if (muscles.isNotEmpty) ...[
          _Heading(l.recapMuscles),
          for (final (name, sets) in muscles.take(_ranked))
            _Line(title: name, value: l.recapSetsCount(wholeSets(sets))),
        ],
        if (recap.patterns.isNotEmpty) ...[
          _Heading(l.recapPatterns),
          for (final MapEntry(key: pattern, value: count) in recap.patterns.entries.take(_ranked))
            _Line(title: patternLabel(pattern, l), value: l.recapSetsCount(wholeSets(count.sets))),
        ],
        if (recap.exercises.isNotEmpty) ...[
          _Heading(l.recapExercises),
          for (final exercise in recap.exercises.take(_ranked))
            _Line(
              title: exercises.lookup(exercise.exerciseId)?.name ?? exercise.exerciseId,
              value: l.recapSetsCount(exercise.sets),
            ),
        ],
      ],
    );
  }
}

/// The month's totals, two to a row in a readable column: three left "9 h 46
/// min" cut short on a phone.
class _Totals extends StatelessWidget {
  final Recap recap;
  final double width;

  const new({required this.recap, required this.width});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tiles = [
      (l.workouts, '${recap.workouts}'),
      (l.recapTimeTrained, trainedTime(l, recap.trained)),
      (l.recapTrainingDays, '${recap.trainingDays}'),
      (l.recapWeeksTrained, l.recapOutOf(recap.weeksTrained, recap.weeks.length)),
      (l.sets, '${recap.sets}'),
      // a month of runs and planks moved no weight: no tile saying 0 kg
      if (recap.volume > 0) (l.totalVolume, recapVolume(l, recap.volume, recap.weightUnit)),
    ];
    final columns = columnsFor(width, maxExtent: 240);
    final tileWidth = (width - tileGutter * (columns - 1)) / columns;

    return Wrap(
      spacing: tileGutter,
      runSpacing: tileGutter,
      children: [
        for (final (label, value) in tiles)
          SizedBox(
            width: tileWidth,
            child: _Stat(label: label, value: value),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const new({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    // read as one thing: "Workouts, 12", not two stops
    return MergeSemantics(
      child: Container(
        padding: const .all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: const .all(.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 4,
          children: [
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: .ellipsis,
            ),
            Text(value, style: textTheme.titleLarge, maxLines: 1, overflow: .ellipsis),
          ],
        ),
      ),
    );
  }
}

/// The month's weeks as a strip of bars, one per week, as tall as its
/// workouts. Its numbers are the weeks-trained tile's, so a screen reader
/// hears them there rather than once a bar.
class _Weeks extends StatelessWidget {
  final Map<DateTime, int> weeks;

  const new({required this.weeks});

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final ColorScheme(:primary, :surfaceContainerHighest) = Theme.of(context).colorScheme;
    final most = weeks.values.fold(1, math.max);

    return ExcludeSemantics(
      child: SizedBox(
        height: _height,
        child: Row(
          crossAxisAlignment: .end,
          spacing: 6,
          children: [
            for (final count in weeks.values)
              Expanded(
                child: Container(
                  // an empty week still holds its place, as a sliver
                  height: math.max(4, _height * count / most),
                  decoration: BoxDecoration(
                    color: count > 0 ? primary : surfaceContainerHighest,
                    borderRadius: const .all(.circular(4)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const new(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(top: 24, bottom: 4),
      child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
    );
  }
}

/// A name and its number on one line, the name giving way first.
class _Line extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;

  const new({required this.title, required this.value, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const .symmetric(vertical: 6),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(title, style: textTheme.bodyLarge, maxLines: 2, overflow: .ellipsis),
                  if (subtitle case final String subtitle)
                    Text(subtitle, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(value, style: textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
