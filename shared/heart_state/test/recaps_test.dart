import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The recap engine (#154, #155): one fold of a period's sets behind the
/// monthly report, the year in review and their share cards.
///
/// The fixture is Muffin's September 2026 — the 1st is a Tuesday — with one
/// August session before it, which only the records may see.
void main() {
  final bench = _Exercise(
    'bench',
    Category.barbell,
    target: Target.chest,
    patterns: ['horizontal_press'],
    primary: ['chest'],
    secondary: ['arms'],
  );
  final thruster = _Exercise(
    'thruster',
    Category.barbell,
    target: Target.legs,
    patterns: ['squat', 'vertical_press'],
    primary: ['legs', 'shoulders'],
  );
  // one the user made and never tagged: placed by its target alone
  final pushUp = _Exercise('push_up', Category.repsOnly, target: Target.chest, patterns: ['horizontal_press']);
  final run = _Exercise('run', Category.cardio, target: Target.other);
  // its row is gone from the device: sets, but nothing to measure them by
  final ghost = _Exercise('ghost', null, target: Target.other);

  final august = DateTime(2026, 8, 20, 18);
  final morning = DateTime(2026, 9, 2, 7);
  final evening = DateTime(2026, 9, 2, 18);
  final midMonth = DateTime(2026, 9, 15, 18);
  final lastWeek = DateTime(2026, 9, 29, 18);
  final october = DateTime(2026, 10, 1, 18);

  final workouts = <RecapWorkout>[
    (id: 'muffin-aug', start: august, trained: const Duration(minutes: 40)),
    (id: 'muffin-run', start: morning, trained: const Duration(minutes: 30)),
    (id: 'muffin-push', start: evening, trained: const Duration(minutes: 50)),
    (id: 'muffin-legs', start: midMonth, trained: const Duration(minutes: 60)),
    (id: 'muffin-heavy', start: lastWeek, trained: const Duration(minutes: 45)),
    (id: 'muffin-oct', start: october, trained: const Duration(minutes: 70)),
  ];

  // oldest workout first, a session's sets together, as the read returns them
  final history = <RecapSet>[
    bench.set('muffin-aug', august, weight: 80, reps: 5),
    pushUp.set('muffin-aug', august, reps: 20),
    run.set('muffin-run', morning, distance: 5, duration: 1800),
    bench.set('muffin-push', evening, weight: 70, reps: 5),
    bench.set('muffin-push', evening, weight: 70, reps: 5),
    bench.set('muffin-push', evening, weight: 75, reps: 3),
    pushUp.set('muffin-push', evening, reps: 25),
    bench.set('muffin-legs', midMonth, weight: 82.5, reps: 2),
    thruster.set('muffin-legs', midMonth, weight: 40, reps: 10),
    thruster.set('muffin-legs', midMonth, weight: 40, reps: 10),
    ghost.set('muffin-legs', midMonth, reps: 10),
    ghost.set('muffin-legs', midMonth, reps: 10),
    ghost.set('muffin-legs', midMonth, reps: 10),
    bench.set('muffin-heavy', lastWeek, weight: 85, reps: 1),
  ];

  final september = RecapPeriod.month(DateTime(2026, 9, 18));
  final afterwards = DateTime(2026, 10, 18);

  Recap recap({
    RecapPeriod? period,
    List<RecapWorkout>? from,
    List<RecapSet>? sets,
    int firstWeekday = DateTime.monday,
    MeasurementUnit weightUnit = MeasurementUnit.metric,
    DateTime? now,
  }) {
    return recapOf(
      period ?? september,
      workouts: from ?? workouts,
      history: sets ?? history,
      firstWeekday: firstWeekday,
      weightUnit: weightUnit,
      now: now ?? afterwards,
    );
  }

  const primary = MuscleTagging.defaultPrimaryShare;
  const secondary = MuscleTagging.defaultSecondaryShare;

  group('RecapPeriod', () {
    test('a month runs from midnight on the 1st to midnight on the next 1st', () {
      expect(september.span, RecapSpan.month);
      expect(september.from, DateTime(2026, 9));
      expect(september.to, DateTime(2026, 10));
      expect(RecapPeriod.month(DateTime(2026, 12, 31, 23)).to, DateTime(2027));
    });

    test('a year runs from New Year to New Year', () {
      final year = RecapPeriod.year(2026);
      expect((year.span, year.from, year.to), (RecapSpan.year, DateTime(2026), DateTime(2027)));
    });

    test('contains its first instant and not its last', () {
      expect(september.contains(DateTime(2026, 9)), isTrue);
      expect(september.contains(DateTime(2026, 9, 30, 23, 59)), isTrue);
      expect(september.contains(DateTime(2026, 10)), isFalse);
      expect(september.contains(DateTime(2026, 8, 31, 23, 59)), isFalse);
    });

    test('previous steps back one of its own span, across the year', () {
      expect(RecapPeriod.month(DateTime(2027, 1, 5)).previous, RecapPeriod.month(DateTime(2026, 12)));
      expect(RecapPeriod.year(2026).previous, RecapPeriod.year(2025));
    });

    test('is a value', () {
      expect(RecapPeriod.month(DateTime(2026, 9, 1)), RecapPeriod.month(DateTime(2026, 9, 30)));
      expect(RecapPeriod.month(DateTime(2026, 1)), isNot(RecapPeriod.year(2026)));
    });
  });

  group('totals', () {
    test('count the finished workouts that started in the period, and nothing outside it', () {
      final september = recap();

      expect(september.workouts, 4);
      expect(september.trained, const Duration(minutes: 30 + 50 + 60 + 45));
      expect(september.isEmpty, isFalse);
    });

    test('training days are calendar days: two sessions on one day are one', () {
      expect(recap().trainingDays, 3);
    });

    test('sets are the period\'s working sets; the August history is not counted', () {
      expect(recap().sets, 12);
    });

    test('volume is weight × reps over lifted sets only, in the unit asked for', () {
      // bench 350 + 350 + 225, 165 and 85; thruster 400 + 400. The push-ups,
      // the run and the ghost's sets move no weight anyone can count
      const kilograms = 925.0 + 165 + 85 + 800;

      expect(recap().volume, kilograms);
      expect(recap().weightUnit, MeasurementUnit.metric);
      expect(recap(weightUnit: .imperial).volume, closeTo(kilograms.asPounds, 1e-9));
      expect(recap(weightUnit: .imperial).weightUnit, MeasurementUnit.imperial);
    });

    test('an empty period says so, with every total at zero', () {
      final empty = recap(period: RecapPeriod.month(DateTime(2026, 7)));

      expect(empty.isEmpty, isTrue);
      expect(
        (empty.workouts, empty.trained, empty.trainingDays, empty.sets, empty.volume),
        (0, Duration.zero, 0, 0, 0.0),
      );
      expect(empty.muscles, isEmpty);
      expect(empty.patterns, isEmpty);
      expect(empty.exercises, isEmpty);
      expect(empty.records, isEmpty);
      expect(empty.lifts, isEmpty);
      expect(empty.weeksTrained, 0);
    });
  });

  group('muscles and patterns', () {
    test('muscles count by the muscle map\'s rule, most sets first', () {
      final muscles = recap().muscles;

      // five bench sets at the primary share and one untagged push-up placed
      // whole by its target
      expect(muscles[MuscleGroupKey.chest], (sets: 5 * primary + 1, sessions: 3, volume: 1175 * primary));
      expect(muscles[MuscleGroupKey.arms], (sets: 5 * secondary, sessions: 3, volume: 1175 * secondary));
      expect(muscles[MuscleGroupKey.legs], (sets: 2 * primary, sessions: 1, volume: 800 * primary));
      expect(muscles[MuscleGroupKey.shoulders], (sets: 2 * primary, sessions: 1, volume: 800 * primary));
      // the run and the ghost place nothing
      expect(muscles.keys, hasLength(4));
      expect(muscles.keys.first, MuscleGroupKey.chest, reason: 'the most-trained muscle leads');
    });

    test('muscles use the shares the lens and the map use', () {
      final row = (
        workoutId: 'w',
        exerciseId: bench.id,
        start: evening,
        movement: bench.movement,
        muscles: bench.muscles,
        target: bench.target,
        sets: 1,
      );
      expect(muscleKeysOf(row), {MuscleGroupKey.chest: primary, MuscleGroupKey.arms: secondary});
      expect(groupSharesOf(MuscleTagging.empty(), Target.chest), {MuscleGroupKey.chest: 1.0});
      expect(groupSharesOf(MuscleTagging.empty(), Target.other), isEmpty);
    });

    test('patterns count every pattern an exercise trains, in full', () {
      final patterns = recap().patterns;

      expect(patterns.keys, ['horizontal_press', 'squat', 'vertical_press']);
      expect(patterns['horizontal_press'], (sets: 6.0, sessions: 3, volume: 1175.0));
      // a thruster set is a squat and an overhead press
      expect(patterns['squat'], (sets: 2.0, sessions: 1, volume: 800.0));
      expect(patterns['vertical_press'], (sets: 2.0, sessions: 1, volume: 800.0));
    });

    test('a key\'s volume is in the unit asked for', () {
      expect(recap(weightUnit: .imperial).patterns['squat']?.volume, closeTo(800.asPounds, 1e-9));
    });
  });

  group('exercises', () {
    test('most-logged first: sets, then sessions, then the order first done', () {
      expect(
        recap().exercises.map((each) => (each.exerciseId, each.sets, each.sessions)),
        [
          ('bench', 5, 3),
          ('ghost', 3, 1),
          ('thruster', 2, 1),
          // tied: the run came first that day
          ('run', 1, 1),
          ('push_up', 1, 1),
        ],
      );
    });

    test('carry their volume, zero for what is not lifted', () {
      final volumes = {for (final each in recap().exercises) each.exerciseId: each.volume};
      expect(volumes, {'bench': 1175.0, 'ghost': 0.0, 'thruster': 800.0, 'run': 0.0, 'push_up': 0.0});
    });
  });

  group('records', () {
    test('are the ones set in the period and still standing at its end, oldest first', () {
      expect(
        recap().records.map((each) => (each.exerciseId, each.record)),
        [
          ('run', 'longestDistance'),
          ('run', 'longestDuration'),
          ('run', 'bestPace'),
          ('push_up', 'mostReps'),
          ('thruster', 'heaviest'),
          ('thruster', 'oneRepMax'),
          ('thruster', 'bestVolume'),
          // mid-month's 82.5 was beaten before the month was out: only the
          // 85 stands. The August 80 × 5 still holds the estimate and the best
          // volume, so neither is September's
          ('bench', 'heaviest'),
        ],
      );
    });

    test('carry the shared fold\'s entry, with what they beat', () {
      final records = recap().records;
      final heaviest = records.singleWhere((each) => each.exerciseId == 'bench');
      final reps = records.singleWhere((each) => each.exerciseId == 'push_up');

      expect(heaviest.category, Category.barbell);
      expect(heaviest.value['weight'], 85.0);
      expect(heaviest.value['workoutId'], 'muffin-heavy');
      expect((heaviest.value['previous'] as Map)['weight'], 82.5);
      expect(heaviest.isFirst, isFalse);

      expect(reps.value['reps'], 25);
      expect((reps.value['previous'] as Map)['reps'], 20);
      expect(reps.isFirst, isFalse);
    });

    test('an exercise\'s first time sets records with nothing to beat', () {
      final firsts = recap().records.where((each) => each.isFirst).map((each) => each.exerciseId).toSet();
      expect(firsts, {'run', 'thruster'});
    });

    test('agree with the exercise\'s own records, folded the same way', () {
      final benchSets = history
          .where((set) => set.exerciseId == 'bench')
          .map(
            (set) => RecordSet(
              weight: set.weight,
              reps: set.reps,
              duration: set.duration,
              distance: set.distance,
              workoutId: set.workoutId,
              at: set.start.toUtc().toIso8601String(),
            ),
          )
          .toList();
      final own = benchSets.toPersonalRecords(Category.barbell)!;

      expect(recap().records.singleWhere((each) => each.exerciseId == 'bench').value, own['heaviest']);
    });

    test('none for an exercise the device cannot measure', () {
      expect(recap().records.where((each) => each.exerciseId == 'ghost'), isEmpty);
    });
  });

  group('lifts', () {
    test('every lifted exercise\'s best within the period, heaviest estimate first', () {
      final lifts = recap().lifts;

      expect(lifts.map((each) => each.exerciseId), ['bench', 'thruster']);

      final best = lifts.first;
      // the August 80 × 5 estimates higher, but it is not this period's
      expect(best.heaviest['weight'], 85.0);
      expect(best.oneRepMax?['value'], closeTo(85, 1e-9));
      expect(best.oneRepMax?['workoutId'], 'muffin-heavy');
    });

    test('are the period alone: no "previous" from inside it', () {
      final best = recap().lifts.first;
      expect(best.heaviest.containsKey('previous'), isFalse);
      expect(best.oneRepMax?.containsKey('previous'), isFalse);
    });
  });

  group('consistency', () {
    test('every week of the period, in the user\'s week, zeros included', () {
      final weeks = recap().weeks;

      expect(weeks, {
        DateTime(2026, 8, 31): 2,
        DateTime(2026, 9, 7): 0,
        DateTime(2026, 9, 14): 1,
        DateTime(2026, 9, 21): 0,
        DateTime(2026, 9, 28): 1,
      });
      expect(recap().weeksTrained, 3);
    });

    test('the user\'s first day moves a workout into the week it belongs to', () {
      // a Sunday: the end of a Monday week, the start of a Sunday one
      final sunday = DateTime(2026, 9, 13, 10);
      final only = [(id: 'muffin-sunday', start: sunday, trained: const Duration(minutes: 30))];

      final monday = recap(from: only, sets: const []).weeks;
      final ownWeek = recap(from: only, sets: const [], firstWeekday: DateTime.sunday).weeks;

      expect(monday[DateTime(2026, 9, 7)], 1);
      expect(ownWeek.keys.first, DateTime(2026, 8, 30));
      expect(ownWeek[DateTime(2026, 9, 13)], 1);
    });

    test('a period under way lists only the weeks and months that have begun', () {
      final soFar = recap(now: DateTime(2026, 9, 16, 9));

      expect(soFar.weeks.keys, [DateTime(2026, 8, 31), DateTime(2026, 9, 7), DateTime(2026, 9, 14)]);
      expect(soFar.months, {DateTime(2026, 9): 4});
    });

    test('a year counts its months, and stops at the current one', () {
      final year = recap(period: RecapPeriod.year(2026));

      expect(year.months.keys, [
        for (final month in Iterable.generate(10, (index) => index + 1)) DateTime(2026, month),
      ]);
      expect(year.months[DateTime(2026, 8)], 1);
      expect(year.months[DateTime(2026, 9)], 4);
      expect(year.months[DateTime(2026, 10)], 1);
      expect(year.workouts, 6);
    });

    test('a year that is over has all its months and every week it touches', () {
      final past = recap(period: RecapPeriod.year(2025), from: const [], sets: const []);

      expect(past.months, hasLength(12));
      // 1 January 2025 was a Wednesday, 31 December too
      expect(past.weeks.keys.first, DateTime(2024, 12, 30));
      expect(past.weeks.keys.last, DateTime(2025, 12, 29));
      expect(past.weeks, hasLength(53));
    });

    test('a year can touch 54 weeks', () {
      // 2012: a leap year from a Sunday to a Monday
      final leap = recap(period: RecapPeriod.year(2012), from: const [], sets: const []);

      expect(leap.weeks.keys.first, DateTime(2011, 12, 26));
      expect(leap.weeks.keys.last, DateTime(2012, 12, 31));
      expect(leap.weeks, hasLength(54));
    });

    test('a year\'s records and lifts come from the same fold', () {
      final year = recap(period: RecapPeriod.year(2026));

      // August's session is inside the year now: the 80 × 5 is the year's
      // best estimate, and the push-ups' first time is in it too
      expect(year.lifts.first.oneRepMax?['workoutId'], 'muffin-aug');
      expect(
        year.records.where((each) => each.exerciseId == 'bench').map((each) => each.record),
        contains('oneRepMax'),
      );
    });
  });
}

class _Exercise {
  final String id;
  final Category? category;
  final Target target;
  final Movement movement;
  final MuscleTagging muscles;

  new(
    this.id,
    this.category, {
    required this.target,
    List<String> patterns = const [],
    List<String> primary = const [],
    List<String> secondary = const [],
  }) : movement = Movement.fromJson({'groups': patterns}),
       muscles = switch (primary) {
         [] => MuscleTagging.empty(),
         _ => MuscleTagging.fromJson({
           'primary': {'ids': <String>[], 'groups': primary},
           'secondary': {'ids': <String>[], 'groups': secondary},
         }),
       };

  RecapSet set(String workout, DateTime start, {double? weight, int? reps, double? duration, double? distance}) {
    return (
      workoutId: workout,
      exerciseId: id,
      start: start,
      category: category,
      movement: movement,
      muscles: muscles,
      target: target,
      weight: weight,
      reps: reps,
      duration: duration,
      distance: distance,
    );
  }
}
