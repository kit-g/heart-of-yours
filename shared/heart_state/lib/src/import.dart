import 'dart:convert';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'export.dart';
import 'goals.dart';
import 'programs.dart';
import 'templates.dart';

/// Why a file is not one this build can import.
enum UnreadableExportReason {
  /// Not JSON, or JSON that is not Heart's envelope.
  notHeart,

  /// Heart's envelope, written by a newer build in a layout this one does not
  /// know.
  newer,
}

/// The file picked is not a Heart JSON export this build can read. Nothing
/// was written.
class UnreadableExport implements Exception {
  final UnreadableExportReason reason;

  const new(this.reason);

  @override
  String toString() => 'UnreadableExport(${reason.name})';
}

/// What importing a Heart JSON export *would* do: the same numbers the server
/// reports for a Strong or Hevy dry run, plus the parts of Heart's own file a
/// workout log does not have.
typedef LocalImportPreview = ({
  int workoutsFound,
  int workoutsAlreadyHere,
  int setsFound,
  int exercisesMatched,

  /// Exercise names that resolve to nothing on this device, each with the
  /// sets that ride on it, in file order — the consent step's input.
  List<({String name, int sets})> exercisesUnmatched,
  int templates,
  int folders,
  int goals,
  int rowsSkipped,
});

/// What an import did.
typedef LocalImportReport = ({
  int workoutsFound,
  int workoutsCreated,
  int workoutsSkipped,
  int setsCreated,
  int setsSkipped,
  int exercisesMatched,

  /// Names that matched nothing and were created as the user's own, on the
  /// user's word.
  List<String> exercisesCreated,
  List<String> exercisesSkipped,
  int templates,
  int folders,
  int goals,
  int rowsSkipped,
});

/// Reads Heart's own JSON export ([ExportSnapshot.toJson]) back into the
/// local store (heart-of-yours#329).
///
/// The store, not the server, on purpose (heart-api#175): with an account the
/// upsync replays what lands here as it would any offline work, and without
/// one the store is all there is.
///
/// The ids in the file are the identity. Anything the store already holds
/// under the file's id is left exactly as it is, so importing a file into the
/// account it came from changes nothing, and importing it twice is importing
/// it once. A custom exercise or folder the store holds under another id but
/// the same name is that one, as the upsync's name-merge has it, and the
/// file's references follow.
///
/// Health data is never part of this: the export carries none, and nothing
/// read here is written anywhere a health value lives.
class DataImport {
  final WorkoutService _workouts;
  final TemplateService _templates;
  final LocalTemplateFolderService _folders;
  final ExerciseService _exercises;
  final LocalGoalService _goals;
  final LocalProgramService? _programs;

  const new({
    required this._workouts,
    required this._templates,
    required this._folders,
    required this._exercises,
    required this._goals,
    this._programs,
  });

  static DataImport of(BuildContext context) {
    return Provider.of<DataImport>(context, listen: false);
  }

  /// The dry run: reads [file] against [userId]'s store and writes nothing.
  Future<LocalImportPreview> preview(String file, String userId) async {
    final plan = await _plan(file, userId, createCustom: const []);
    return (
      workoutsFound: plan.workoutsFound,
      workoutsAlreadyHere: plan.workoutsHere,
      setsFound: plan.setsFound,
      exercisesMatched: plan.exercisesMatched,
      exercisesUnmatched: plan.unmatched,
      templates: plan.templates.length,
      folders: plan.folders.length,
      goals: plan.goals.length,
      rowsSkipped: plan.rowsSkipped,
    );
  }

  /// Writes what [file] holds and [userId]'s store does not.
  ///
  /// [createCustom] is the user's word on the unmatched names, as for the
  /// server's import: null brings every one over as a custom exercise, a list
  /// exactly those, and the sets on a name left out stay behind, counted.
  ///
  /// Order is the references': exercises, folders, programs, templates,
  /// workouts, the programs' history, unit preferences, goals. Not one transaction — the services are separate
  /// stores — but every write is keyed on an id the store did not hold, so an
  /// import cut short is finished by importing the same file again.
  Future<LocalImportReport> import(String file, String userId, {List<String>? createCustom}) async {
    final plan = await _plan(file, userId, createCustom: createCustom);

    if (plan.exercises.isNotEmpty) await _exercises.storeExercises(plan.exercises, userId: userId);
    for (final folder in plan.folders) {
      await _folders.storeFolder(folder, userId);
    }
    for (final program in plan.programs) {
      await _programs?.storeProgram(program, userId);
    }
    if (plan.templates.isNotEmpty) await _templates.storeTemplates(plan.templates, userId: userId);
    // unsynced, as a workout finished offline is: the upsync, or the sweep
    // behind it, is what takes it to an account
    for (final workout in plan.workouts) {
      await _workouts.finishWorkout(workout, userId);
    }
    for (final action in plan.programActions) {
      await _programs?.storeProgramAction(action);
    }
    for (final base in plan.programBases) {
      await _programs?.storeProgramBase(base);
    }
    for (final skip in plan.skips) {
      await _programs?.storeSkip(skip, userId);
    }
    for (final MapEntry(key: exerciseId, value: unit) in plan.units.entries) {
      await _exercises.setExerciseUnit(exerciseName: exerciseId, userId: userId, unit: unit);
    }
    for (final goal in plan.goals) {
      await _goals.createGoal(goal, userId);
    }

    return (
      workoutsFound: plan.workoutsFound,
      workoutsCreated: plan.workouts.length,
      workoutsSkipped: plan.workoutsHere,
      setsCreated: plan.workouts.fold(0, (sum, workout) => sum + workout.fold(0, (sum, each) => sum + each.length)),
      setsSkipped: plan.setsDeclined,
      exercisesMatched: plan.exercisesMatched,
      exercisesCreated: plan.created,
      exercisesSkipped: [
        for (final (:name, sets: _) in plan.unmatched)
          if (!plan.created.contains(name)) name,
      ],
      templates: plan.templates.length,
      folders: plan.folders.length,
      goals: plan.goals.length,
      rowsSkipped: plan.rowsSkipped,
    );
  }

  Future<_Plan> _plan(String file, String userId, {required List<String>? createCustom}) async {
    final envelope = _envelope(file);
    final plan = _Plan();

    final (_, stored) = await _exercises.getExercises(userId: userId);
    final resolver = _Resolver(stored);

    // the file's own exercises first: they are what its workouts name
    for (final Map raw in _list(envelope['exercises'])) {
      final custom = plan.read(() => Exercise.fromJson(raw).copyWith(isMine: true));
      if (custom == null) continue;
      if (resolver.adopt(custom)) plan.exercises.add(custom);
    }

    final workouts = _list(envelope['workouts']);
    final templates = _list(envelope['templates']);

    // every name the file uses that this device cannot resolve, with its sets
    final unmatched = <String, int>{};
    for (final Map raw in [...workouts, ...templates]) {
      for (final Map entry in _list(raw['exercises'])) {
        if (resolver.resolve(entry['exercise']) != null) continue;
        if (_name(entry['exercise']) case String name) {
          unmatched[name] = (unmatched[name] ?? 0) + _list(entry['sets']).length;
        }
      }
    }
    plan.unmatched = [for (final MapEntry(key: name, value: sets) in unmatched.entries) (name: name, sets: sets)];

    // the user's word on those: each one approved becomes a custom, shaped by
    // what its sets record — the server's rule for the same question
    for (final name in unmatched.keys) {
      if (createCustom != null && !createCustom.contains(name)) continue;
      final custom = Exercise.fromJson({
        'id': uuidV7(),
        'name': name,
        'category': _category(name, [...workouts, ...templates]).value,
        'target': Target.other.value,
        'own': 1,
      });
      resolver.adopt(custom);
      plan.exercises.add(custom);
      plan.created.add(name);
    }
    plan.exercisesMatched = resolver.matched;

    final storedFolders = await _folders.getFolders(userId);
    final folders = _Folders(storedFolders);
    for (final Map raw in _list(envelope['folders'])) {
      final folder = plan.read(() => TemplateFolder.fromJson(raw));
      if (folder == null) continue;
      if (folders.adopt(folder)) plan.folders.add(folder);
    }

    // a program comes over whole, its history with it; without a store to
    // hold programs, what names one is filed under nothing
    final programs = _programs;
    final heldPrograms = {
      for (final each in await programs?.getPrograms(userId) ?? const <Program>[]) ?each.id,
    };
    if (programs != null) {
      for (final Map raw in _list(envelope['programs'])) {
        if (heldPrograms.contains(raw['id']?.toString())) continue;
        final program = plan.read(() => Program.fromJson(raw));
        if (program?.id case final String id) {
          plan.programs.add(program!);
          heldPrograms.add(id);
        }
      }
      final imported = {for (final each in plan.programs) each.id};
      final heldActions = {for (final each in await programs.getProgramActions(userId)) each.id};
      for (final Map raw in _list(envelope['programActions'])) {
        if (heldActions.contains(raw['id']?.toString())) continue;
        final action = plan.read(() => ProgramAction.fromJson(raw));
        if (action == null || !imported.contains(action.programId)) continue;
        // a ladder's advance names its two exercises as they are called here,
        // as a base does, or there is nothing it moved between
        switch (action) {
          case ProgramAction(kind: .advance, :final from?, :final to?):
            switch ((resolver.byFileId(from), resolver.byFileId(to))) {
              case (final Exercise from, final Exercise to):
                plan.programActions.add(ProgramAction.fromJson({...raw, 'from': from.id, 'to': to.id}));
              case _:
                plan.rowsSkipped++;
            }
          case _:
            plan.programActions.add(action);
        }
      }
      final heldBases = {for (final each in await programs.getProgramBases(userId)) each.id};
      for (final Map raw in _list(envelope['programBases'])) {
        if (heldBases.contains(raw['id']?.toString())) continue;
        final base = plan.read(() => ProgramBase.fromJson(raw));
        if (base == null || !imported.contains(base.programId)) continue;
        // the exercise it grows, as it is called here, or nothing to grow
        switch (resolver.byFileId(base.exerciseId)) {
          case final Exercise exercise:
            plan.programBases.add(ProgramBase.fromJson({...raw, 'exerciseId': exercise.id}));
          case null:
            plan.rowsSkipped++;
        }
      }
    }
    String? programOf(Map raw) {
      return switch (raw['programId']) {
        final String id when heldPrograms.contains(id) => id,
        _ => null,
      };
    }

    if (programs != null) {
      final heldSkips = {for (final each in await programs.getSkips(userId)) each.id};
      for (final Map raw in _list(envelope['skips'])) {
        if (heldSkips.contains(raw['id']?.toString())) continue;
        // its program is a link: one this store has none of reads as none
        if (plan.read(() => TrainingSkip.fromJson({...raw, 'programId': programOf(raw)}))
            case final TrainingSkip skip) {
          plan.skips.add(skip);
        }
      }
    }

    final storedTemplates = {for (final each in await _templates.getTemplates(userId)) each.id};
    for (final Map raw in templates) {
      if (storedTemplates.contains(raw['id']?.toString())) continue;
      final (entries, _) = _entries(raw, resolver);
      // nothing left to do in it once the declined names are gone
      if (entries.isEmpty) continue;
      // filed under the folder the file's became here, or unfiled
      final folder = switch (raw['folder']) {
        {'id': final Object id} => folders.resolve(id.toString()),
        _ => null,
      };
      final template = plan.read(
        () => Template.fromJson({
          for (final MapEntry(:key, :value) in raw.entries)
            if (key != 'folder') key: value,
          'folder': ?folder?.toMap(),
          'programId': programOf(raw),
          'exercises': entries,
        }),
      );
      if (template != null) plan.templates.add(template);
    }

    final storedWorkouts = {for (final each in await _workouts.getWorkoutHistory(userId) ?? const <Workout>[]) each.id};
    plan.workoutsFound = workouts.length;
    for (final Map raw in workouts) {
      plan.setsFound += _list(raw['exercises']).fold(0, (sum, entry) => sum + _list(entry['sets']).length);
      if (storedWorkouts.contains(raw['id']?.toString())) {
        plan.workoutsHere++;
        continue;
      }
      final (entries, declined) = _entries(raw, resolver);
      plan.setsDeclined += declined;
      // every exercise in it declined: its sets are counted above, and an
      // empty workout is not one the user logged
      if (entries.isEmpty) continue;
      // photos stay behind: they live in the account that took them, and a
      // link into it means nothing here
      final workout = plan.read(
        () => Workout.fromJson({...raw, 'exercises': entries, 'programId': programOf(raw)}..remove('images')),
      );
      if (workout == null) {
        // counted as found but neither created nor here: one that could not
        // be read, said so on the report
        plan.workoutsFound--;
        continue;
      }
      plan.workouts.add(workout);
    }

    final units = await _exercises.getExerciseUnits(userId);
    if (envelope['units'] case {'exercises': Map perExercise}) {
      for (final MapEntry(:key, :value) in perExercise.entries) {
        final exercise = resolver.byFileId(key.toString());
        final unit = MeasurementUnit.values.asNameMap()[value];
        // the store's own preference wins: the file is history, the store is
        // what the user chose since
        if (exercise == null || unit == null || units.containsKey(exercise.id)) continue;
        plan.units[exercise.id] = unit;
      }
    }

    final storedGoals = {
      for (final archived in [false, true])
        for (final each in await _goals.getTargetUserGoals(
          requesterId: userId,
          targetUserId: userId,
          archived: archived,
        ))
          each.id,
    };
    for (final Map raw in _list(envelope['goals'])) {
      if (storedGoals.contains(raw['id']?.toString())) continue;
      final goal = plan.read(() => Goal.fromJson(raw));
      if (goal == null) continue;
      switch (goal.exerciseId) {
        case null:
          plan.goals.add(goal);
        case final String id:
          // a goal on an exercise this device has no row for has nothing to
          // measure, and the store would refuse it
          switch (resolver.byFileId(id)) {
            case final Exercise exercise:
              plan.goals.add(Goal.fromJson({...raw, 'exerciseId': exercise.id}));
            case null:
              plan.rowsSkipped++;
          }
      }
    }

    return plan;
  }

  /// [raw]'s exercises with each reference swapped for the exercise it
  /// resolves to, and the sets on the ones that resolve to nothing counted.
  static (List<Map>, int) _entries(Map raw, _Resolver resolver) {
    final kept = <Map>[];
    var declined = 0;
    for (final Map entry in _list(raw['exercises'])) {
      switch (resolver.resolve(entry['exercise'])) {
        case final Exercise exercise:
          kept.add({...entry, 'exercise': exercise.toMap()});
        case null:
          declined += _list(entry['sets']).length;
      }
    }
    return (kept, declined);
  }

  /// The best-effort category for a name the user agreed to create: the
  /// equipment in the name where it maps cleanly, else what its sets record.
  /// The server's rule for the same question on a Strong or Hevy import.
  static Category _category(String name, List<Map> sessions) {
    final sets = [
      for (final Map session in sessions)
        for (final Map entry in _list(session['exercises']))
          if (_name(entry['exercise']) == name) ..._list(entry['sets']),
    ];
    bool records(String field) => sets.any((set) => set[field] != null);

    return switch (name.toLowerCase()) {
      final n when n.contains('(barbell)') => .barbell,
      final n when n.contains('(dumbbell)') || n.contains('(kettlebell)') => .dumbbell,
      final n when n.contains('(machine)') || n.contains('(cable)') || n.contains('(smith machine)') => .machine,
      _ when records('distance') => records('weight') ? .weightedDistance : .cardio,
      _ when records('duration') => records('weight') ? .weightedDuration : .duration,
      _ when records('weight') => .weightedBodyWeight,
      _ => .repsOnly,
    };
  }

  static Map _envelope(String file) {
    final Object? decoded;
    try {
      decoded = jsonDecode(file);
    } on FormatException {
      throw const UnreadableExport(.notHeart);
    }
    return switch (decoded) {
      // 1 wrote the whole exercise where 2 writes its name; both read
      {'schemaVersion': int version} when version >= 1 && version <= exportSchemaVersion => decoded,
      {'schemaVersion': int version} when version > exportSchemaVersion => throw const UnreadableExport(.newer),
      _ => throw const UnreadableExport(.notHeart),
    };
  }
}

/// What an import will write, and the numbers that describe it.
class _Plan {
  final exercises = <Exercise>[];
  final created = <String>[];
  final folders = <TemplateFolder>[];
  final templates = <Template>[];
  final workouts = <Workout>[];
  final units = <String, MeasurementUnit>{};
  final goals = <Goal>[];
  final programs = <Program>[];
  final programActions = <ProgramAction>[];
  final programBases = <ProgramBase>[];
  final skips = <TrainingSkip>[];
  List<({String name, int sets})> unmatched = const [];
  int workoutsFound = 0;

  /// Already in the store under the file's id.
  int workoutsHere = 0;
  int setsFound = 0;
  int setsDeclined = 0;
  int exercisesMatched = 0;

  /// Rows the models refused: a shape a newer build wrote, or a hand edit.
  int rowsSkipped = 0;

  T? read<T>(T Function() parse) {
    try {
      return parse();
    } on Object {
      rowsSkipped++;
      return null;
    }
  }
}

/// Exercise references in the file, resolved against the store.
///
/// A reference is the exercise's name (schema 2) or its whole row (schema 1).
/// A row resolves by id first; a name resolves to the file's own exercises,
/// then to the store's by exact name, then ignoring case.
class _Resolver {
  final Map<String, Exercise> _byId;
  final Map<String, Exercise> _byName;
  final Map<String, Exercise> _byFolded;
  final Map<String, Exercise> _mineByFolded;

  /// The file's ids for its own exercises, onto the exercise each became here.
  final _fileIds = <String, Exercise>{};

  /// The names the file uses, onto what each became here.
  final _fileNames = <String, Exercise>{};

  final _matched = <String>{};

  new(Iterable<Exercise> stored)
    : _byId = {for (final each in stored) each.id: each},
      _byName = {for (final each in stored) each.name: each},
      _byFolded = {for (final each in stored) _fold(each.name): each},
      _mineByFolded = {
        for (final each in stored)
          if (each.isMine) _fold(each.name): each,
      };

  static String _fold(String name) => name.trim().toLowerCase();

  /// Takes the file's own [exercise]: true when it is new to the store and
  /// needs writing, false when the store has it — under its id, or as the
  /// user's own by that name.
  bool adopt(Exercise exercise) {
    final here = _byId[exercise.id] ?? _mineByFolded[_fold(exercise.name)];
    final resolved = here ?? exercise;
    _fileIds[exercise.id] = resolved;
    _fileNames[exercise.name] = resolved;
    return here == null;
  }

  /// The exercise the file's id [id] names on this device: one of the file's
  /// own, else one the store holds under it.
  Exercise? byFileId(String id) => _fileIds[id] ?? _byId[id];

  Exercise? resolve(Object? reference) {
    final resolved = switch (reference) {
      {'id': final Object id} when byFileId(id.toString()) != null => byFileId(id.toString()),
      _ => switch (_name(reference)) {
        final String name => _fileNames[name] ?? _byName[name] ?? _byFolded[_fold(name)],
        null => null,
      },
    };
    if (resolved != null) _matched.add(resolved.id);
    return resolved;
  }

  int get matched => _matched.length;
}

String? _name(Object? reference) {
  return switch (reference) {
    final String name => name,
    {'name': final String name} => name,
    _ => null,
  };
}

List<Map> _list(Object? value) {
  return switch (value) {
    final List l => l.whereType<Map>().toList(),
    _ => const [],
  };
}

/// The store's folders, and the file's onto them.
class _Folders {
  final Map<String, TemplateFolder> _byId;
  final Map<String, TemplateFolder> _byFolded;
  final _fileIds = <String, TemplateFolder>{};

  new(Iterable<TemplateFolder> stored)
    : _byId = {
        for (final each in stored)
          if (each.id case final String id) id: each,
      },
      _byFolded = {for (final each in stored) _Resolver._fold(each.name): each};

  /// As [_Resolver.adopt]: true when [folder] is new to the store.
  bool adopt(TemplateFolder folder) {
    final here = _byId[folder.id] ?? _byFolded[_Resolver._fold(folder.name)];
    if (folder.id case final String id) _fileIds[id] = here ?? folder;
    return here == null;
  }

  TemplateFolder? resolve(String id) => _fileIds[id] ?? _byId[id];
}
