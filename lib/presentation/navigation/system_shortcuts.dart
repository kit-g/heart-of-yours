import 'package:flutter/foundation.dart';
import 'package:heart/core/env/shortcuts.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart/presentation/navigation/commands.dart';
import 'package:heart/presentation/widgets/workout/rest.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the system's assistant layer told what it can name (#285): the
/// templates, the user's own first and then the samples, as [ShortcutTemplate]s
/// — so "Start Push day in Heart" resolves with the app not running. Published
/// again whenever they change, and only when they changed.
///
/// And the rest a voice command acts on (#98): the exercise the user is on,
/// its rest setting, and the words of the rest's notification, so "start
/// rest" works with the app not running too.
///
/// Switched off, the feature publishes nothing: the assistant then knows no
/// template and no rest, and a bare "start a workout" opens the app to do
/// nothing, as #284 has it. Never asked and on both publish, since reaching
/// for a shortcut is the yes.
class SystemShortcutsPresenter extends StatefulWidget {
  final Widget child;

  /// The platform's layer, or null where there is none (tests, the web).
  final SystemShortcuts? shortcuts;

  const new({super.key, required this.child, this.shortcuts});

  @override
  State<SystemShortcutsPresenter> createState() => _SystemShortcutsPresenterState();
}

class _SystemShortcutsPresenterState extends State<SystemShortcutsPresenter> {
  Templates? _templates;
  Preferences? _preferences;
  Workouts? _workouts;
  Timers? _timers;
  Auth? _auth;
  Exercises? _exercises;

  /// What was last told, so the same list is not sent again on every repaint.
  /// What [SystemShortcuts.setEnabled] was last told; null before the first.
  bool? _publishedEnabled;
  List<ShortcutTemplate>? _published;
  ShortcutRest? _publishedRest;
  bool _restPublished = false;
  ShortcutSet? _publishedSet;
  bool _setPublished = false;
  List<ShortcutExercise>? _publishedExercises;
  String? _publishedSession;
  bool _sessionPublished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final templates = Templates.of(context);
    if (!identical(templates, _templates)) {
      _templates?.removeListener(_sync);
      _templates = templates..addListener(_sync);
    }
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_sync);
      _preferences = preferences..addListener(_sync);
    }
    final workouts = Workouts.of(context);
    if (!identical(workouts, _workouts)) {
      _workouts?.removeListener(_sync);
      _workouts = workouts..addListener(_sync);
    }
    final timers = Timers.of(context);
    if (!identical(timers, _timers)) {
      _timers?.removeListener(_sync);
      _timers = timers..addListener(_sync);
    }
    // the rest's words follow the language and the unit
    L.of(context);
    final auth = Auth.of(context);
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_sync);
      _auth = auth..addListener(_sync);
    }
    final exercises = Exercises.of(context);
    if (!identical(exercises, _exercises)) {
      _exercises?.removeListener(_sync);
      _exercises = exercises..addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    _templates?.removeListener(_sync);
    _preferences?.removeListener(_sync);
    _workouts?.removeListener(_sync);
    _timers?.removeListener(_sync);
    _auth?.removeListener(_sync);
    _exercises?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _sync() {
    final shortcuts = widget.shortcuts;
    if (shortcuts == null) return;
    final off = _preferences?.featureAnswer(.shortcuts) == FeatureAnswer.off;
    if (_publishedEnabled != !off) {
      _publishedEnabled = !off;
      shortcuts.setEnabled(enabled: !off);
    }
    final list = switch ((off, _templates)) {
      (true, _) || (_, null) => const <ShortcutTemplate>[],
      (false, Templates templates) => [...templates, ...templates.samples].map(_named).nonNulls.toList(),
    };
    if (_published case List<ShortcutTemplate> published when listEquals(published, list)) {
      // nothing new to name
    } else {
      _published = list;
      shortcuts.setTemplates(list);
    }

    final rest = switch (off) {
      true => null,
      false => _rest(),
    };
    if (!_restPublished || rest != _publishedRest) {
      _restPublished = true;
      _publishedRest = rest;
      shortcuts.setRest(rest);
    }

    final set = switch (off) {
      true => null,
      false => _nextSet(),
    };
    if (!_setPublished || set != _publishedSet) {
      _setPublished = true;
      _publishedSet = set;
      shortcuts.setNextSet(set);
    }

    // the questions (#288): whose training, and the exercises they can name
    final session = switch (off) {
      true => null,
      false => _auth?.user?.id,
    };
    if (!_sessionPublished || session != _publishedSession) {
      _sessionPublished = true;
      _publishedSession = session;
      shortcuts.setSession(session);
    }
    final exercises = switch ((off, _exercises)) {
      (true, _) || (_, null) => const <ShortcutExercise>[],
      (false, Exercises exercises) => [
        for (final exercise in exercises) ShortcutExercise(id: exercise.id, name: exercise.name),
      ],
    };
    if (_publishedExercises case List<ShortcutExercise> published when listEquals(published, exercises)) return;
    _publishedExercises = exercises;
    shortcuts.setExercises(exercises);
  }

  /// The set a voice command logs (#287): the one up next, with what it takes
  /// and what it already holds, in the unit its exercise is shown in.
  ShortcutSet? _nextSet() {
    final workouts = _workouts;
    final workout = workouts?.activeWorkout;
    if (workouts == null || workout == null) return null;
    if (upNextIn(workout, after: workouts.latestMarkedSet) case (
      :WorkoutExercise exercise,
      set: ExerciseSet set,
      number: _,
    )) {
      final (weighted, counted) = measuresOf(exercise);
      final unit = unitOf(context, exercise);
      final l = L.of(context);
      return (
        workoutId: workout.id,
        setId: set.id,
        exerciseName: exercise.exercise.name,
        weighted: weighted,
        counted: counted,
        unit: switch (unit) {
          .imperial => l.lbs,
          .metric => l.kg,
        },
        weight: switch ((weighted, set.weight)) {
          (true, double weight) => Preferences.of(context).weightValue(weight, unit: unit),
          _ => null,
        },
        reps: counted ? set.reps : null,
        completable: set.canBeCompleted,
      );
    }
    return null;
  }

  /// The rest a voice command acts on (#98): the exercise the user is on —
  /// the next set's, or the last one once every set is done — with its rest
  /// setting and its notification's words. Null with no workout running.
  ShortcutRest? _rest() {
    final workouts = _workouts;
    final workout = workouts?.activeWorkout;
    if (workouts == null || workout == null) return null;
    final upNext = upNextIn(workout, after: workouts.latestMarkedSet);
    final exercise = upNext?.exercise ?? workout.lastOrNull;
    if (exercise == null) return null;
    final next = switch (upNext) {
      (:WorkoutExercise exercise, set: ExerciseSet set, number: _) => (exercise, set),
      _ => null,
    };
    final copy = restNotificationCopy(context, exercise, next: next);
    return (
      workoutId: workout.id,
      exerciseId: exercise.id,
      seconds: _timers?[exercise.exercise.id],
      title: copy.title,
      body: copy.body,
      subtitle: copy.subtitle,
    );
  }

  /// A template without a name is nothing to say to Siri.
  static ShortcutTemplate? _named(Template template) {
    return switch (template.name?.trim()) {
      String name when name.isNotEmpty => ShortcutTemplate(id: template.id, name: name),
      _ => null,
    };
  }
}
