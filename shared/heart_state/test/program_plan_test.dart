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

  Workout plan(Template session, {Map<String, ProgramBase> bases = const {}, bool lighter = false, Deload? deload}) {
    return planSession(
      session,
      program: Program(id: 'p1', name: 'Waves', deload: deload),
      bases: bases,
      lighter: lighter,
      round: round,
    );
  }

  test('a share of a base is a weight to aim for, rounded to a plate', () {
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
    // 78 and 102: 77.5 and 102.5 on the bar
    expect(first.target![.weight], TargetRange.exactly(77.5));
    expect(second.target![.weight], TargetRange.exactly(102.5));
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

  test('a lighter cycle takes the load off and the supplemental sets first', () {
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
    expect(squatDay.skip(1).map((set) => set.target![.weight]), [
      TargetRange.exactly(72.5),
      TargetRange.exactly(72.5),
    ]);
    // one set is one set, at 90%
    expect(frontDay.single.weight, 55);
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
}
