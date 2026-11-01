import 'package:heart_models/heart_models.dart';
import 'package:intl/intl.dart';

/// The words a [Transcript] is written in. Copy, so presentation implements
/// it from the localizations; this package only arranges what it is given.
///
/// Every method takes values the formatter has already put into words or
/// numbers — a count, a date range, a note — never a model.
abstract interface class TranscriptCopy {
  /// The opening line of a single workout.
  String get workoutIntro;

  /// The opening line of a period: [workouts] in it, over [range].
  String periodIntro(int workouts, String range);

  /// The opening line of one exercise's history: [sessions] of [exercise],
  /// over [range], and the [shape] its sets are written in.
  String exerciseIntro(String exercise, String shape, int sessions, String range);

  /// How to read what follows: units come once, with each exercise, and the
  /// way times are written.
  String get howToRead;

  /// A workout with no name.
  String get untitled;

  /// The program a workout counted toward.
  String program(String name);

  /// A note, on a workout or on one exercise of it.
  String note(String note);

  /// [Workout.calories]: an estimate from MET values, said as one.
  String energyEstimate(String kcal);

  /// How an exercise's sets read — "kg × reps", "km / time" — in its units.
  String shape(Category category, {required MeasurementUnit weight, required MeasurementUnit distance});

  /// A set's type in words; null for a plain working set, which needs none.
  String? setType(SetType type);

  /// A set's rated effort.
  String rpe(String value);

  /// The records a set holds, already named.
  String records(List<String> kinds);

  /// What did not fit: [workouts] earlier ones, over [range].
  String leftOutWorkouts(int workouts, String range);

  /// What did not fit of one exercise's history: [sessions] earlier ones.
  String leftOutSessions(int sessions, String range);
}

/// A user's own training as plain text for an AI assistant of their choice
/// (#259): one workout, a period, or one exercise's history.
///
/// Written to be read by a model without follow-up questions: each exercise
/// says once what its numbers are and in which units, then every set is a
/// line of bare numbers with its type, RPE and records beside it.
///
/// Bounded: past [maxLength] characters the oldest workouts are left out, and
/// the text says how many, and from when. The newest always stays.
///
/// **No health data.** Nothing here reads the health store, and of the two
/// health-adjacent fields the models carry, [WorkoutExercise.met] (measured by
/// a wearable) is never read. [Workout.calories] goes out only as what it is,
/// an estimate from MET values, and says so (`docs/2026-09-05.health-data.md`).
class Transcript {
  final TranscriptCopy copy;

  /// For dates and numbers.
  final String locale;

  final MeasurementUnit weightUnit;

  final MeasurementUnit distanceUnit;

  /// Per-exercise overrides of both units, by exercise id.
  final Map<ExerciseId, MeasurementUnit> exerciseUnits;

  /// Program names, by id: a workout that counted toward one says which.
  final Map<String, String> programs;

  /// The records each set holds, by set id, already named.
  final Map<String, List<String>> records;

  /// The most characters a transcript runs to, short of the one workout that
  /// always goes in. About 6,000 tokens: enough for a month of training, and
  /// within what any assistant takes in one message.
  final int maxLength;

  static const defaultMaxLength = 24000;

  new({
    required this.copy,
    required this.locale,
    required this.weightUnit,
    required this.distanceUnit,
    this.exerciseUnits = const {},
    this.programs = const {},
    this.records = const {},
    this.maxLength = defaultMaxLength,
  }) : _date = DateFormat.yMMMEd(locale).add_Hm(),
       _day = DateFormat.yMMMd(locale),
       _number = NumberFormat('0.##', locale),
       _tenth = NumberFormat('0.#', locale);

  final DateFormat _date;
  final DateFormat _day;
  final NumberFormat _number;

  /// A weight, to the tenth at most, as the app shows it.
  final NumberFormat _tenth;

  /// One finished workout.
  String workout(Workout workout) {
    final shapes = <ExerciseId>{};
    return [copy.workoutIntro, copy.howToRead, '', _workout(workout, shapes)].join('\n');
  }

  /// Finished workouts over a period, oldest first; the oldest are the ones
  /// left out when they do not all fit.
  String period(Iterable<Workout> workouts) {
    final finished = _finished(workouts);
    final kept = _fit(finished.reversed, (each) => _workout(each, {})).toList().reversed.toList();
    final shapes = <ExerciseId>{};
    final blocks = kept.map((each) => _workout(each, shapes));
    final left = finished.take(finished.length - kept.length).toList();
    return [
      copy.periodIntro(kept.length, _range(kept)),
      copy.howToRead,
      for (final block in blocks) ...['', block],
      if (left.isNotEmpty) ...['', copy.leftOutWorkouts(left.length, _range(left))],
    ].join('\n');
  }

  /// Every finished session of [exercise] among [workouts], oldest first,
  /// with the workout each was part of.
  String exercise(Exercise exercise, Iterable<Workout> workouts) {
    final sessions = [
      for (final workout in _finished(workouts))
        if (_entriesOf(workout, exercise.id) case final entries when entries.isNotEmpty) (workout, entries),
    ];
    final kept = _fit(sessions.reversed, _session).toList().reversed.toList();
    final left = sessions.take(sessions.length - kept.length).map((each) => each.$1).toList();
    return [
      copy.exerciseIntro(exercise.name, _shapeOf(exercise), kept.length, _range([for (final (w, _) in kept) w])),
      copy.howToRead,
      for (final session in kept) ...['', _session(session)],
      if (left.isNotEmpty) ...['', copy.leftOutSessions(left.length, _range(left))],
    ].join('\n');
  }

  /// Completed, oldest first.
  static List<Workout> _finished(Iterable<Workout> workouts) {
    return workouts.where((each) => each.isCompleted).toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// The newest-first [items] that fit in [maxLength] once rendered, newest
  /// first. The first always does: a transcript of nothing helps nobody.
  Iterable<T> _fit<T>(Iterable<T> items, String Function(T) render) sync* {
    var length = 0;
    for (final (index, item) in items.indexed) {
      length += render(item).length + 1;
      if (index > 0 && length > maxLength) return;
      yield item;
    }
  }

  List<WorkoutExercise> _entriesOf(Workout workout, ExerciseId id) {
    return workout.where((each) => each.exercise.id == id && each.any((set) => set.isCompleted)).toList();
  }

  String _workout(Workout workout, Set<ExerciseId> shapes) {
    return [
      _heading(workout),
      if (workout.programId case String id when programs[id] != null) copy.program(programs[id]!),
      if (workout.note case String note when note.trim().isNotEmpty) copy.note(note.trim()),
      if (workout.calories case double kcal when kcal > 0) copy.energyEstimate(_number.format(kcal.round())),
      for (final entry in workout.where((each) => each.any((set) => set.isCompleted)))
        _entry(entry, named: true, withShape: shapes.add(entry.exercise.id)),
    ].join('\n');
  }

  String _session((Workout, List<WorkoutExercise>) session) {
    final (workout, entries) = session;
    return [
      _heading(workout),
      for (final entry in entries) _entry(entry, named: false, withShape: false),
    ].join('\n');
  }

  /// "Push day · Mon, Sep 22, 2026 18:04 · 1:02:13"
  String _heading(Workout workout) {
    return [
      switch (workout.name?.trim()) {
        String name when name.isNotEmpty => name,
        _ => copy.untitled,
      },
      _date.format(workout.start.toLocal()),
      if (workout.duration case Duration duration) _clock(duration.inSeconds),
    ].join(' · ');
  }

  String _entry(WorkoutExercise entry, {required bool named, required bool withShape}) {
    final exercise = entry.exercise;
    final completed = entry.where((set) => set.isCompleted);
    return [
      if (named) withShape ? '- ${exercise.name} (${_shapeOf(exercise)})' : '- ${exercise.name}',
      for (final (index, set) in completed.indexed) '  ${index + 1}. ${_set(set)}',
      if (entry.note case String note when note.trim().isNotEmpty) '  ${copy.note(note.trim())}',
    ].join('\n');
  }

  String _shapeOf(Exercise exercise) {
    return copy.shape(
      exercise.category,
      weight: exerciseUnits[exercise.id] ?? weightUnit,
      distance: exerciseUnits[exercise.id] ?? distanceUnit,
    );
  }

  /// The set's numbers in its exercise's shape, then what else it carries.
  String _set(ExerciseSet set) {
    return [
      _measures(set),
      ?copy.setType(set.setType),
      if (set.rpe case double rpe) copy.rpe(_number.format(rpe)),
      if (records[set.id] case List<String> kinds when kinds.isNotEmpty) copy.records(kinds),
    ].join(', ');
  }

  String _measures(ExerciseSet set) {
    final unit = exerciseUnits[set.exercise.id];
    final weight = _optional(set.weight, (kg) => _weight(kg, unit ?? weightUnit));
    final reps = set.reps?.toString() ?? '–';
    final time = _optional(set.duration?.toDouble(), (seconds) => _clock(seconds.round()));
    return switch (set.category) {
      .barbell || .dumbbell || .machine => '$weight × $reps',
      .weightedBodyWeight => '+${_optional(set.weight, (kg) => _weight(kg, unit ?? weightUnit), none: '0')} × $reps',
      .assistedBodyWeight => '−${_optional(set.weight, (kg) => _weight(kg, unit ?? weightUnit), none: '0')} × $reps',
      .repsOnly => reps,
      .cardio => '${_optional(set.distance, (km) => _distance(km, unit ?? distanceUnit))} / $time',
      .duration => time,
      .weightedDistance => '$weight / ${_optional(set.distance, (km) => _shortDistance(km, unit ?? distanceUnit))}',
      .weightedDuration => '$weight / $time',
    };
  }

  String _optional(double? value, String Function(double) format, {String none = '–'}) {
    return switch (value) {
      double v when v > 0 => format(v),
      _ => none,
    };
  }

  String _weight(double kilograms, MeasurementUnit unit) {
    return switch (unit) {
      .metric => _tenth.format(kilograms),
      .imperial => _tenth.format(kilograms.asPounds),
    };
  }

  String _distance(double kilometers, MeasurementUnit unit) {
    return switch (unit) {
      .metric => _number.format(kilometers),
      .imperial => _number.format(kilometers.asMiles),
    };
  }

  /// A carry's distance, in metres or yards.
  String _shortDistance(double kilometers, MeasurementUnit unit) {
    return switch (unit) {
      .metric => _number.format((kilometers * 1000).round()),
      .imperial => _number.format((kilometers * 1093.6133).round()),
    };
  }

  /// m:ss under an hour, h:mm:ss over it.
  static String _clock(int seconds) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final (h, m, s) = (seconds ~/ 3600, seconds ~/ 60 % 60, seconds % 60);
    return h > 0 ? '$h:${pad(m)}:${pad(s)}' : '$m:${pad(s)}';
  }

  /// "Sep 1, 2026 – Sep 28, 2026", or the one day; [workouts] oldest first.
  String _range(List<Workout> workouts) {
    final days = workouts.map((each) => _day.format(each.start.toLocal())).toList();
    return switch (days) {
      [] => '',
      [final only] => only,
      [final first, ..., final last] when first == last => first,
      [final first, ..., final last] => '$first – $last',
    };
  }
}
