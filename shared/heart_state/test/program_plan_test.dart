import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/program_plan.dart';

void main() {
  const squat = {'id': 'squat', 'name': 'Squat', 'category': 'Barbell', 'target': 'Legs'};
  const front = {'id': 'front', 'name': 'Front Squat', 'category': 'Barbell', 'target': 'Legs'};

  var sets = 0;
  Map set(Map target, {String type = 'normal', num? weight}) => {
    'id': 'set-${sets++}',
    'set_type': type,
    'weight': ?weight,
    'target': target,
  };

  Template session(List<Map> exercises) => Template.fromJson({
    'id': 's1',
    'name': 'Squat day',
    'order': 0,
    'programId': 'p1',
    'exercises': exercises,
  });

  ProgramBase base(String key, num value, {String? slot}) =>
      ProgramBase(id: 'b-$key', programId: 'p1', exerciseId: key, slot: slot, value: value, at: DateTime.utc(2026, 10));

  // to the nearest 2.5 kg, as a metric user's plates go
  num round(Exercise _, num kilograms) => (kilograms / 2.5).round() * 2.5;

  Workout plan(
    Template session, {
    Map<String, ProgramBase> bases = const {},
    bool lighter = false,
    Deload? deload,
    Map<String, GrowthRule> rules = const {},
    Map<String, int> stages = const {},
  }) {
    final program = Program(id: 'p1', name: 'Waves', deload: deload, rules: rules);
    final now = DateTime.utc(2026, 10, 14, 12);
    return planSession(
      session,
      program: program,
      position: ProgramPosition.of(
        program,
        marks: const [],
        actions: [if (lighter) ProgramAction(programId: 'p1', kind: .lighter, at: now)],
        now: now,
        firstWeekday: DateTime.monday,
      ),
      bases: bases,
      stages: stages,
      round: round,
    );
  }

  test('a share of a base is a weight to aim for, rounded down to the step', () {
    final workout = plan(
      session([
        {
          'id': 'te1',
          'exercise': squat,
          'sets': [
            set({
              'share': 0.65,
              'reps': {'min': 5, 'max': 5},
            }),
            set({
              'share': 0.85,
              'reps': {'min': 5},
            }),
          ],
        },
      ]),
      bases: {'squat': base('squat', 120)},
    );

    final [first, second] = workout.first.toList();
    // 78 and 102, down to the 2.5 step: what the API and MCP plan too
    expect(first.target![.weight], TargetRange.exactly(77.5));
    expect(second.target![.weight], TargetRange.exactly(100));
    expect(first.target!.share, 0.65, reason: 'the line still says where it comes from');
    expect(first.weight, isNull, reason: 'a plan is never a logged value');
  });

  test("a share of another lift's base, and a slot's own, win over the exercise's", () {
    final workout = plan(
      session([
        {
          'id': 'te1',
          'exercise': squat,
          'sets': [
            set({'share': 0.5}),
          ],
        },
        {
          'id': 'te2',
          'exercise': front,
          'sets': [
            set({'share': 0.5, 'of': 'squat'}),
          ],
        },
      ]),
      bases: {
        'squat': base('squat', 100),
        // this occurrence of the squat keeps its own
        'te1': base('squat', 140, slot: 'te1'),
        'front': base('front', 60),
      },
    );

    final [squatDay, frontDay] = workout.toList();
    expect(squatDay.first.target![.weight], TargetRange.exactly(70));
    expect(frontDay.first.target![.weight], TargetRange.exactly(50));
  });

  test('without a base a share stays a share, and the cells take the rest', () {
    final workout = plan(
      session([
        {
          'id': 'te1',
          'exercise': squat,
          'sets': [
            set({
              'share': 0.65,
              'reps': {'min': 5, 'max': 5},
            }),
          ],
        },
      ]),
    );

    final target = workout.first.first.target!;
    expect(target[.weight], isNull);
    expect(target[.reps], TargetRange.exactly(5));
  });

  test('a lighter cycle takes the load off worked-out weights and keeps the first of the working sets', () {
    final workout = plan(
      session([
        {
          'id': 'te1',
          'exercise': squat,
          'sets': [
            set({}, type: 'warmup'),
            set({'share': 0.8}),
            set({'share': 0.8}),
            set({
              'weight': {'min': 100, 'max': 100},
            }),
            set({'share': 0.6, 'supplemental': true}),
          ],
        },
        {
          'id': 'te2',
          'exercise': front,
          'sets': [
            set({}, weight: 60),
          ],
        },
      ]),
      bases: {'squat': base('squat', 100)},
      lighter: true,
      deload: const Deload(every: 4, load: 0.9, volume: 0.5),
    );

    final [squatDay, frontDay] = workout.toList();
    expect(squatDay.map((set) => set.setType), [SetType.warmup, SetType.normal, SetType.normal]);
    // 80 at 90%, down to the step
    expect(squatDay.skip(1).map((set) => set.target![.weight]), [
      TargetRange.exactly(70),
      TargetRange.exactly(70),
    ]);
    // a weight the template stores is not worked out, so it stays
    expect(frontDay.single.weight, 60);
  });

  test('a lighter cycle leaves warm-ups alone and never adds sets', () {
    final workout = plan(
      session([
        {
          'id': 'te1',
          'exercise': squat,
          'sets': [
            set({}, type: 'warmup'),
          ],
        },
        {
          'id': 'te2',
          'exercise': front,
          'sets': [
            set({}, weight: 60),
            set({}, weight: 60),
          ],
        },
      ]),
      lighter: true,
      // more than all of them: keeps what there is
      deload: const Deload(every: 4, load: 0.9, volume: 1.5),
    );

    final [warmups, frontDay] = workout.toList();
    expect(warmups.map((set) => set.setType), [SetType.warmup]);
    expect(frontDay, hasLength(2));
  });

  test("an occurrence's own rule and base, and a share of another occurrence's base", () {
    final workout = plan(
      session([
        {
          'id': 'te1',
          'exercise': squat,
          'sets': [set({})],
        },
        {
          'id': 'te2',
          'exercise': front,
          'sets': [
            set({'share': 0.9, 'of': 'squat', 'ofSlot': 'te1'}),
          ],
        },
      ]),
      rules: {'te1': const AddWeight(step: 2.5)},
      bases: {
        'squat': base('squat', 80),
        'te1': base('squat', 100, slot: 'te1'),
      },
    );

    final [heavy, front90] = workout.toList();
    // its own base under its own rule: the occurrence, not the exercise
    expect(heavy.first.target![.weight], TargetRange.exactly(100));
    expect(front90.first.target![.weight], TargetRange.exactly(90));
  });

  test('a stages rule lays out the stage it is on', () {
    final workout = plan(
      session([
        {
          'id': 'te1',
          'exercise': squat,
          'sets': [
            set({}, type: 'warmup'),
            set({
              'reps': {'min': 3},
            }),
          ],
        },
      ]),
      rules: {
        'squat': const Stages(
          stages: [Stage(sets: 5, reps: 3, amrap: true), Stage(sets: 6, reps: 2, amrap: true)],
          step: 2.5,
        ),
      },
      stages: {'squat': 1},
      bases: {'squat': base('squat', 100)},
    );

    final sets = workout.single.toList();
    expect(sets.map((set) => set.setType), [SetType.warmup, ...List.filled(6, SetType.normal)]);
    expect(sets.skip(1).map((set) => set.target![.reps]), [
      ...List.filled(5, TargetRange.exactly(2)),
      const TargetRange(min: 2),
    ]);
    expect(sets.skip(1).map((set) => set.target![.weight]), List.filled(6, TargetRange.exactly(100)));
    expect(sets.map((set) => set.id).toSet(), hasLength(7), reason: 'each laid-out set is a set of its own');
  });
}
