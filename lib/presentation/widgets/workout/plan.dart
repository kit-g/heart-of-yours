part of 'workout_detail.dart';

/// A program's plan on the sheet (#349): the one line under an exercise that
/// says what its targets are and where they come from. The values themselves
/// are the rows' ghosts; this says the rest — a share of which max, how much
/// in reserve, how far an AMRAP goes, what follows, what the slot takes.

/// [exercise]'s plan in a line: "3×5 at 65% of your max · stop with 2 in
/// reserve · then 5×5 at 65% of your max". Null when it carries none.
String? planLine(
  BuildContext context,
  WorkoutExercise exercise, {
  required String Function(String exerciseId) nameOf,
}) {
  final l = L.of(context);
  final percent = NumberFormat.percentPattern(Localizations.localeOf(context).toString());
  final cells = _Cells(
    Preferences.of(context),
    Exercises.of(context).unitFor(exercise.exercise.id),
    exercise.exercise.category,
  );

  final planned = exercise.where((set) => set.setType != .warmup && set.target != null);
  final main = planned.where((set) => !set.target!.supplemental).toList();
  final supplemental = planned.where((set) => set.target!.supplemental).toList();

  final parts = [
    ?_setsLine(l, percent, cells, main, nameOf),
    if (main.map((set) => set.target!).expand((target) => target.ranges.values).where(_capped).firstOrNull
        case TargetRange(:final num max))
      l.planUpTo(max),
    if (main.map((set) => set.target!.rir).nonNulls.firstOrNull case final num rir) l.planReserve(rir),
    if (_setsLine(l, percent, cells, supplemental, nameOf) case final String then) l.planThen(then),
    if (exercise.totalReps case final TargetRange total) l.planTotalReps(_rangeText(total, (value) => '$value')),
    if (exercise.pattern case final String pattern) l.planOpenSlot(PatternFilter(pattern).label(l)),
  ];
  return switch (parts) {
    [] => null,
    _ => parts.join(' · '),
  };
}

bool _capped(TargetRange range) => range.amrap && range.max != null;

/// [sets] as "3×5 at 65% of your max": how many of what, the reps (or time,
/// or distance) each asks for, and what share of whose max. Sets that ask
/// for different amounts are listed: "5, 3, 1+".
String? _setsLine(
  L l,
  NumberFormat percent,
  _Cells cells,
  List<ExerciseSet> sets,
  String Function(String exerciseId) nameOf,
) {
  if (sets.isEmpty) return null;
  final measure = const <TargetMeasure>[.reps, .duration, .distance]
      .where(
        (measure) => sets.any((set) => set.target![measure] != null),
      )
      .firstOrNull;
  final amounts = switch (measure) {
    final TargetMeasure measure => sets.map(
      (set) => switch (set.target![measure]) {
        // a capped AMRAP reads as an AMRAP here; its cap has words of its own
        final TargetRange range when _capped(range) => '${cells.shown(measure, range.min)}+',
        final TargetRange range => _rangeText(range, (value) => cells.shown(measure, value)),
        null => '–',
      },
    ),
    null => const <String>[],
  };
  final count = switch (amounts.toSet().toList()) {
    [] => null,
    [final amount] => l.planSetsReps(sets.length, amount),
    _ => amounts.join(', '),
  };

  final shares = sets.map((set) => set.target!.share).nonNulls.toList();
  final share = switch (shares) {
    [] => null,
    _ => switch ((shares.reduce(min), shares.reduce(max))) {
      (final low, final high) when low == high => percent.format(low),
      (final low, final high) => '${percent.format(low)}–${percent.format(high)}',
    },
  };
  final of = switch ((share, sets.map((set) => set.target!.of).nonNulls.firstOrNull)) {
    (null, _) => null,
    (final String share, final String other) => l.planShareOf(share, nameOf(other)),
    (final String share, null) => l.planShareOfMax(share),
  };
  return switch ([?count, ?of]) {
    [] => null,
    final parts => parts.join(' '),
  };
}

/// The plan's line, faint, under the exercise's name.
class const _PlanLine(final String line) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Padding(
      padding: const .symmetric(horizontal: 8),
      child: Text(line, style: textTheme.bodySmall?.copyWith(color: colorScheme.tertiary)),
    );
  }
}

/// The note at the top of a lighter cycle's workout (#349), said once rather
/// than under every exercise.
class const LighterWeekNote({super.key, required final Deload? deload}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final percent = NumberFormat.percentPattern(Localizations.localeOf(context).toString());
    final line = L
        .of(context)
        .planLighterWeek(
          percent.format(deload?.load ?? Deload.defaultLoad),
          percent.format(deload?.volume ?? Deload.defaultVolume),
        );
    return Padding(
      padding: const .fromLTRB(16, 8, 16, 0),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.spa_outlined, size: 18, color: colorScheme.tertiary),
          Expanded(
            child: Text(line, style: textTheme.bodyMedium?.copyWith(color: colorScheme.tertiary)),
          ),
        ],
      ),
    );
  }
}
