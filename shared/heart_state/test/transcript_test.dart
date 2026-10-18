// Copy for AI (#259): the text a user hands to an assistant. Held to exact
// strings where the layout is the point, and to the rules the layout cannot
// show on its own — nothing from the health contract appears, and what does
// not fit is said rather than silently dropped.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Plain English, so the tests read the layout and not a translation.
class _Copy implements TranscriptCopy {
  const new();

  @override
  String get workoutIntro => 'A workout from my log.';

  @override
  String periodIntro(int workouts, String range) => '$workouts workouts from my log, $range.';

  @override
  String exerciseIntro(String exercise, String shape, int sessions, String range) {
    return '$exercise ($shape) from my log: $sessions sessions, $range.';
  }

  @override
  String get howToRead => 'Units come once per exercise.';

  @override
  String get untitled => 'Workout';

  @override
  String program(String name) => 'Program: $name';

  @override
  String note(String note) => 'Note: $note';

  @override
  String energyEstimate(String kcal) => 'Energy: about $kcal kcal, a MET estimate';

  @override
  String shape(Category category, {required MeasurementUnit weight, required MeasurementUnit distance}) {
    final w = switch (weight) {
      .metric => 'kg',
      .imperial => 'lb',
    };
    final (d, short) = switch (distance) {
      .metric => ('km', 'm'),
      .imperial => ('mi', 'yd'),
    };
    return switch (category) {
      .barbell || .dumbbell || .machine => '$w × reps',
      .weightedBodyWeight => '+$w × reps',
      .assistedBodyWeight => '−$w × reps',
      .repsOnly => 'reps',
      .cardio => '$d / time',
      .duration => 'time',
      .weightedDistance => '$w / $short',
      .weightedDuration => '$w / time',
    };
  }

  @override
  String? setType(SetType type) {
    return switch (type) {
      .normal => null,
      .warmup => 'warm-up',
      .drop => 'drop set',
      .failure => 'to failure',
    };
  }

  @override
  String rpe(String value) => 'RPE $value';

  @override
  String records(List<String> kinds) => 'record: ${kinds.join(', ')}';

  @override
  String leftOutWorkouts(int workouts, String range) => '$workouts earlier workouts left out, $range.';

  @override
  String leftOutSessions(int sessions, String range) => '$sessions earlier sessions left out, $range.';
}

/// The formatter's own source, from the package (a plain `flutter test`) or
/// from the repo root (`make test`, which names the package's path).
String _source() {
  return [
    'lib/src/transcript.dart',
    'shared/heart_state/lib/src/transcript.dart',
  ].map(File.new).firstWhere((file) => file.existsSync()).readAsStringSync();
}

Map<String, dynamic> _exercise(String id, String name, String category) {
  return {'id': id, 'name': name, 'category': category, 'target': 'Other'};
}

final _bench = _exercise('bench', 'Bench Press', 'Barbell');
final _pullUp = _exercise('pull-up', 'Pull-up', 'Weighted Body Weight');
final _assisted = _exercise('assisted-dip', 'Assisted Dip', 'Assisted Body Weight');
final _pushUp = _exercise('push-up', 'Push-up', 'Reps Only');
final _run = _exercise('run', 'Run', 'Cardio');
final _plank = _exercise('plank', 'Plank', 'Duration');
final _carry = _exercise('carry', "Farmer's Carry", 'Weighted Distance');
final _hold = _exercise('hold', 'Weighted Plank', 'Weighted Duration');

/// A finished workout; [start] is local wall time, so the text reads the same
/// in every time zone the suite runs in.
Workout _workout(
  String id,
  String start, {
  String? name = 'Push day',
  int minutes = 60,
  List<Map<String, dynamic>> exercises = const [],
  bool finished = true,
  Object? calories,
  String? note,
  String? programId,
}) {
  final begin = DateTime.parse(start);
  return Workout.fromJson({
    'id': id,
    'name': name,
    'start': begin.toIso8601String(),
    'end': finished ? begin.add(Duration(minutes: minutes)).toIso8601String() : '',
    'calories': ?calories,
    'note': ?note,
    'programId': ?programId,
    'exercises': [
      for (final (order, each) in exercises.indexed) {...each, 'id': '$id-e$order', 'order': order},
    ],
    'synced': 1,
  });
}

Map<String, dynamic> _entry(Map exercise, List<Map<String, dynamic>> sets, {String? note, double? met}) {
  return {
    'exercise': exercise,
    'note': ?note,
    'met': ?met,
    'sets': [
      for (final set in sets) {'completed': 1, ...set},
    ],
  };
}

Transcript _transcript({
  MeasurementUnit weight = .metric,
  MeasurementUnit distance = .metric,
  Map<ExerciseId, MeasurementUnit> exerciseUnits = const {},
  Map<String, String> programs = const {},
  Map<String, List<String>> records = const {},
  int maxLength = Transcript.defaultMaxLength,
  String locale = 'en_US',
}) {
  return Transcript(
    copy: const _Copy(),
    locale: locale,
    weightUnit: weight,
    distanceUnit: distance,
    exerciseUnits: exerciseUnits,
    programs: programs,
    records: records,
    maxLength: maxLength,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('one workout', () {
    test('reads as a heading, its context, then each exercise and its sets', () {
      final workout = _workout(
        'w1',
        '2026-09-22T18:04:00',
        minutes: 62,
        note: 'felt strong',
        programId: 'p1',
        exercises: [
          _entry(
            _bench,
            [
              {'id': 's1', 'weight': 40, 'reps': 10, 'set_type': 'warmup'},
              {'id': 's2', 'weight': 80, 'reps': 5, 'rpe': 8},
              {'id': 's3', 'weight': 62.5, 'reps': 8, 'set_type': 'drop', 'rpe': 9.5},
              {'id': 's4', 'weight': 60, 'reps': 6, 'set_type': 'failure'},
            ],
            note: 'pause at the chest',
          ),
          _entry(_plank, [
            {'id': 's5', 'duration': 75},
          ]),
        ],
      );

      final text = _transcript(
        programs: {'p1': 'Muffin 5/3/1'},
        records: {
          's2': ['Max weight', 'Estimated 1RM'],
        },
      ).workout(workout);

      expect(
        text,
        'A workout from my log.\n'
        'Units come once per exercise.\n'
        '\n'
        'Push day · Tue, Sep 22, 2026 18:04 · 1:02:00\n'
        'Program: Muffin 5/3/1\n'
        'Note: felt strong\n'
        '- Bench Press (kg × reps)\n'
        '  1. 40 × 10, warm-up\n'
        '  2. 80 × 5, RPE 8, record: Max weight, Estimated 1RM\n'
        '  3. 62.5 × 8, drop set, RPE 9.5\n'
        '  4. 60 × 6, to failure\n'
        '  Note: pause at the chest\n'
        '- Plank (time)\n'
        '  1. 1:15',
      );
    });

    test('every category writes its own measures, in its own shape', () {
      final workout = _workout(
        'w1',
        '2026-09-22T18:00:00',
        exercises: [
          _entry(_pullUp, [
            {'id': 'a', 'weight': 20, 'reps': 8},
            {'id': 'b', 'reps': 10},
          ]),
          _entry(_assisted, [
            {'id': 'c', 'weight': 15, 'reps': 6},
          ]),
          _entry(_pushUp, [
            {'id': 'd', 'reps': 25},
          ]),
          _entry(_run, [
            {'id': 'e', 'distance': 5.2, 'duration': 1530},
          ]),
          _entry(_carry, [
            {'id': 'f', 'weight': 40, 'distance': .03},
          ]),
          _entry(_hold, [
            {'id': 'g', 'weight': 20, 'duration': 4000},
          ]),
        ],
      );

      final text = _transcript().workout(workout);

      expect(text, contains('- Pull-up (+kg × reps)\n  1. +20 × 8\n  2. +0 × 10'));
      expect(text, contains('- Assisted Dip (−kg × reps)\n  1. −15 × 6'));
      expect(text, contains('- Push-up (reps)\n  1. 25'));
      expect(text, contains('- Run (km / time)\n  1. 5.2 / 25:30'));
      expect(text, contains("- Farmer's Carry (kg / m)\n  1. 40 / 30"));
      expect(text, contains('- Weighted Plank (kg / time)\n  1. 20 / 1:06:40'));
    });

    test('imperial units convert, and an exercise of its own keeps its own', () {
      final workout = _workout(
        'w1',
        '2026-09-22T18:00:00',
        exercises: [
          _entry(_bench, [
            {'id': 'a', 'weight': 100, 'reps': 5},
          ]),
          _entry(_run, [
            {'id': 'b', 'distance': 10, 'duration': 3000},
          ]),
          _entry(_carry, [
            {'id': 'c', 'weight': 50, 'distance': .05},
          ]),
        ],
      );

      final text = _transcript(
        weight: .imperial,
        distance: .imperial,
        exerciseUnits: {'run': .metric},
      ).workout(workout);

      expect(text, contains('- Bench Press (lb × reps)\n  1. 220.5 × 5'));
      expect(text, contains('- Run (km / time)\n  1. 10 / 50:00'));
      expect(text, contains("- Farmer's Carry (lb / yd)\n  1. 110.2 / 55"));
    });

    test('a weight reads to the tenth, as the app shows it', () {
      final workout = _workout(
        'w1',
        '2026-09-22T18:00:00',
        exercises: [
          _entry(_bench, [
            // 35 lb, stored in kilograms
            {'id': 'a', 'weight': 15.8757, 'reps': 5},
          ]),
        ],
      );

      expect(_transcript().workout(workout), contains('  1. 15.9 × 5'));
      expect(_transcript(weight: .imperial).workout(workout), contains('  1. 35 × 5'));
    });

    test('numbers and dates follow the locale', () {
      final workout = _workout(
        'w1',
        '2026-09-22T18:00:00',
        exercises: [
          _entry(_bench, [
            {'id': 'a', 'weight': 62.5, 'reps': 5},
          ]),
        ],
      );

      final text = _transcript(locale: 'fr').workout(workout);

      expect(text, contains('62,5 × 5'));
      expect(text, contains('22 sept. 2026'));
    });

    test('sets not done, and exercises with none done, stay out', () {
      final workout = _workout(
        'w1',
        '2026-09-22T18:00:00',
        exercises: [
          _entry(_bench, [
            {'id': 'a', 'weight': 80, 'reps': 5},
            {'id': 'b', 'weight': 85, 'reps': 3, 'completed': 0},
          ]),
          _entry(_plank, [
            {'id': 'c', 'duration': 60, 'completed': 0},
          ]),
        ],
      );

      final text = _transcript().workout(workout);

      expect(text, isNot(contains('85')));
      expect(text, isNot(contains('Plank')));
      expect(text, contains('  1. 80 × 5'));
    });

    test('a nameless workout is called one, and a blank note says nothing', () {
      final workout = _workout(
        'w1',
        '2026-09-22T18:00:00',
        name: null,
        note: '   ',
        exercises: [
          _entry(_pushUp, [
            {'id': 'a', 'reps': 20},
          ]),
        ],
      );

      final text = _transcript().workout(workout);

      expect(text, contains('\nWorkout · Tue, Sep 22, 2026 18:00 · 1:00:00\n'));
      expect(text, isNot(contains('Note:')));
    });

    test('a program it no longer knows goes unmentioned', () {
      final workout = _workout('w1', '2026-09-22T18:00:00', programId: 'gone');
      expect(_transcript().workout(workout), isNot(contains('Program')));
    });
  });

  group('no health data', () {
    test('the estimated energy goes out, labelled as the estimate it is', () {
      final workout = _workout('w1', '2026-09-22T18:00:00', calories: 321.6);
      expect(_transcript().workout(workout), contains('Energy: about 322 kcal, a MET estimate'));
    });

    test('a wearable-measured MET never appears, in any scope', () {
      // a value no other field could produce
      const measured = 9.8765;
      final workouts = [
        _workout(
          'w1',
          '2026-09-22T18:00:00',
          exercises: [
            _entry(
              _bench,
              [
                {'id': 'a', 'weight': 80, 'reps': 5},
              ],
              met: measured,
            ),
          ],
        ),
      ];
      final transcript = _transcript();
      final texts = [
        transcript.workout(workouts.single),
        transcript.period(workouts),
        transcript.exercise(Exercise.fromJson(_bench), workouts),
      ];

      for (final text in texts) {
        expect(text, isNot(contains('9.87')));
        expect(text, isNot(contains('9,87')));
        expect(text.toLowerCase(), isNot(contains('met:')));
      }
    });

    test('the formatter cannot reach a health value: no health import, no measured MET, no health vocabulary', () {
      // A source check, on purpose: the runtime tests above prove what this
      // build writes; this proves what it can read. A health value would have
      // to come through one of these doors, and all of them are shut.
      final source = _source();
      final code = source.split('\n').where((line) => !line.trimLeft().startsWith('///')).join('\n');

      expect(code, isNot(contains('heart_health')));
      expect(code, isNot(contains('health.dart')));
      expect(code, isNot(contains(RegExp(r'\.met\b'))));
      for (final word in [
        'HealthMetric',
        'heartRate',
        'restingHeartRate',
        'hrv',
        'sleep',
        'bodyMass',
        'activeEnergy',
        'weightKg',
      ]) {
        expect(code.toLowerCase(), isNot(contains(word.toLowerCase())), reason: word);
      }
    });

    test('the copy it is written in has no word for a health value', () {
      // what presentation can be asked to put into words: workout facts only
      final source = _source();
      final copy = source.substring(
        source.indexOf('abstract interface class TranscriptCopy'),
        source.indexOf('class Transcript {'),
      );
      final members = RegExp(r'^  String\??\s+(?:get\s+)?(\w+)', multiLine: true).allMatches(copy).map((m) => m[1]);

      expect(members.toSet(), {
        'workoutIntro',
        'periodIntro',
        'exerciseIntro',
        'howToRead',
        'untitled',
        'program',
        'note',
        'energyEstimate',
        'shape',
        'setType',
        'rpe',
        'records',
        'leftOutWorkouts',
        'leftOutSessions',
      });
    });
  });

  group('a period', () {
    final workouts = [
      _workout(
        'w2',
        '2026-09-24T07:00:00',
        name: 'Pull day',
        exercises: [
          _entry(_bench, [
            {'id': 'b', 'weight': 82.5, 'reps': 5},
          ]),
        ],
      ),
      _workout(
        'w1',
        '2026-09-22T18:00:00',
        exercises: [
          _entry(_bench, [
            {'id': 'a', 'weight': 80, 'reps': 5},
          ]),
        ],
      ),
      _workout('active', '2026-09-25T18:00:00', finished: false, name: 'Still going'),
    ];

    test('oldest first, finished only, and each exercise names its units once', () {
      final text = _transcript().period(workouts);

      expect(
        text,
        '2 workouts from my log, Sep 22, 2026 – Sep 24, 2026.\n'
        'Units come once per exercise.\n'
        '\n'
        'Push day · Tue, Sep 22, 2026 18:00 · 1:00:00\n'
        '- Bench Press (kg × reps)\n'
        '  1. 80 × 5\n'
        '\n'
        'Pull day · Thu, Sep 24, 2026 07:00 · 1:00:00\n'
        '- Bench Press\n'
        '  1. 82.5 × 5',
      );
    });

    test('past its length, the oldest go, and the text says how many and from when', () {
      final many = List.generate(
        10,
        (i) => _workout(
          'w$i',
          '2026-09-${(i + 1).toString().padLeft(2, '0')}T18:00:00',
          name: 'Day $i',
          exercises: [
            _entry(_bench, [
              {'id': 's$i', 'weight': 80, 'reps': 5},
            ]),
          ],
        ),
      );
      final one = _transcript().workout(many.first).split('\n\n').last.length;

      final text = _transcript(maxLength: one * 3 + 10).period(many);

      expect(text, startsWith('3 workouts from my log, Sep 8, 2026 – Sep 10, 2026.'));
      expect(text, contains('Day 9'));
      expect(text, isNot(contains('Day 6')));
      expect(text, endsWith('7 earlier workouts left out, Sep 1, 2026 – Sep 7, 2026.'));
    });

    test('the newest goes in whole, however long it is', () {
      final text = _transcript(maxLength: 10).period(workouts);
      expect(text, contains('Pull day'));
      expect(text, endsWith('1 earlier workouts left out, Sep 22, 2026.'));
    });

    test('nothing to say about what fits says nothing about leaving out', () {
      expect(_transcript().period(workouts), isNot(contains('left out')));
    });
  });

  group("one exercise's history", () {
    final workouts = [
      _workout(
        'w1',
        '2026-09-22T18:00:00',
        exercises: [
          _entry(_pushUp, [
            {'id': 'p', 'reps': 30},
          ]),
          _entry(
            _bench,
            [
              {'id': 'a', 'weight': 80, 'reps': 5, 'rpe': 7},
            ],
            note: 'elbows in',
          ),
        ],
      ),
      _workout(
        'w2',
        '2026-09-24T07:00:00',
        name: 'Arms',
        exercises: [
          _entry(_pushUp, [
            {'id': 'q', 'reps': 35},
          ]),
        ],
      ),
      _workout(
        'w3',
        '2026-09-26T07:00:00',
        name: 'Heavy',
        exercises: [
          _entry(_bench, [
            {'id': 'b', 'weight': 85, 'reps': 3},
          ]),
        ],
      ),
    ];

    test('only its sessions, oldest first, its shape said once up top', () {
      final text = _transcript(
        records: {
          'b': ['Max weight'],
        },
      ).exercise(Exercise.fromJson(_bench), workouts);

      expect(
        text,
        'Bench Press (kg × reps) from my log: 2 sessions, Sep 22, 2026 – Sep 26, 2026.\n'
        'Units come once per exercise.\n'
        '\n'
        'Push day · Tue, Sep 22, 2026 18:00 · 1:00:00\n'
        '  1. 80 × 5, RPE 7\n'
        '  Note: elbows in\n'
        '\n'
        'Heavy · Sat, Sep 26, 2026 07:00 · 1:00:00\n'
        '  1. 85 × 3, record: Max weight',
      );
    });

    test('past its length, the oldest sessions go, and it says so', () {
      final text = _transcript(maxLength: 10).exercise(Exercise.fromJson(_bench), workouts);
      expect(text, contains('Heavy'));
      expect(text, isNot(contains('80 × 5')));
      expect(text, endsWith('1 earlier sessions left out, Sep 22, 2026.'));
    });
  });
}
