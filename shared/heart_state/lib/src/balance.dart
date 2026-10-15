import 'lens.dart';

/// One side of a balance pair (#342): its content key, which names it, and
/// the movement patterns whose sets it counts.
typedef BalanceSide = ({String key, Set<String> patterns});

/// Two sides set against each other: push against pull, hinge against squat
/// (`docs/2026-10-11.pattern-lens.md`, rule 3).
typedef BalancePair = ({String key, BalanceSide left, BalanceSide right});

/// What a pair gathered over a window: each side's sets, fractional
/// underneath (rule 8), and in how many of the window's weeks either side was
/// trained at all.
typedef BalanceCount = ({BalancePair pair, double left, double right, int weeks});

/// The fewest sets, across both sides, a pair needs before its two bars mean
/// anything. Below it one good week reads as a lopsided habit.
const balanceMinimumSets = 6;

/// The fewest weeks a pair needs to have been trained in, for the same reason.
const balanceMinimumWeeks = 2;

extension BalanceCountEnough on BalanceCount {
  /// Whether there is enough logged to draw the pair rather than say so.
  bool get enough => left + right >= balanceMinimumSets && weeks >= balanceMinimumWeeks;
}

/// The pairs in the shape content would serve them: the library owns the
/// pattern vocabulary (rule 6), and pairs are a fact about that vocabulary.
/// Held here until the exercise library serves its own; [readBalancePairs]
/// is the reader for either.
const balanceContent = [
  {
    'key': 'push_pull',
    'left': {
      'key': 'push',
      'patterns': ['horizontal_press', 'incline_press', 'decline_press', 'vertical_press', 'chest_dip'],
    },
    'right': {
      'key': 'pull',
      'patterns': ['horizontal_row', 'vertical_pull'],
    },
  },
  {
    'key': 'hinge_squat',
    'left': {
      'key': 'hinge',
      'patterns': ['deadlift_floor', 'hip_hinge_stifflegged'],
    },
    'right': {
      'key': 'squat',
      'patterns': ['squat_bilateral', 'lunge_split'],
    },
  },
  {
    'key': 'elbow',
    'left': {
      'key': 'elbow_flexion',
      'patterns': ['elbow_flexion'],
    },
    'right': {
      'key': 'elbow_extension',
      'patterns': ['elbow_extension'],
    },
  },
  {
    'key': 'knee',
    'left': {
      'key': 'knee_extension',
      'patterns': ['knee_extension'],
    },
    'right': {
      'key': 'knee_flexion',
      'patterns': ['knee_flexion'],
    },
  },
];

/// The pairs [json] describes, read tolerantly: an entry this build cannot
/// read is left out rather than failing the rest.
List<BalancePair> readBalancePairs(Object? json) {
  BalanceSide? side(Object? json) {
    return switch (json) {
      {'key': String key, 'patterns': List patterns} when patterns.isNotEmpty => (
        key: key,
        patterns: patterns.whereType<String>().toSet(),
      ),
      _ => null,
    };
  }

  return switch (json) {
    List entries => [
      for (final entry in entries)
        if (entry case {'key': String key, 'left': final left, 'right': final right})
          if ((side(left), side(right)) case (BalanceSide left, BalanceSide right))
            (key: key, left: left, right: right),
    ],
    _ => const [],
  };
}

/// The pairs Heart sets against each other.
final balancePairs = readBalancePairs(balanceContent);

/// [rows] counted into [pairs] over the window [weeks] start, a row's week
/// being [weekOfStart] of its start: a row's sets count toward a side once
/// when any of its exercise's patterns is on that side. Rows outside the
/// window are left out; a week counts toward [BalanceCount.weeks] when either
/// side was trained in it.
List<BalanceCount> countBalance(
  Iterable<LensSets> rows, {
  required Iterable<BalancePair> pairs,
  required List<DateTime> weeks,
  required DateTime Function(DateTime start) weekOfStart,
}) {
  final window = weeks.toSet();
  final inWindow = rows.where((row) => window.contains(weekOfStart(row.start))).toList();
  return [for (final pair in pairs) _count(pair, inWindow, weekOfStart)];
}

BalanceCount _count(BalancePair pair, List<LensSets> rows, DateTime Function(DateTime start) weekOfStart) {
  Iterable<LensSets> on(BalanceSide side) => rows.where((row) => row.movement.groups.any(side.patterns.contains));
  double sets(Iterable<LensSets> rows) => rows.fold(.0, (sum, row) => sum + row.sets);
  final (left, right) = (on(pair.left), on(pair.right));
  return (
    pair: pair,
    left: sets(left),
    right: sets(right),
    weeks: {for (final row in left.followedBy(right)) weekOfStart(row.start)}.length,
  );
}
