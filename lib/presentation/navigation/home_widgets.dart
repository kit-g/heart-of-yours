import 'dart:convert';

import 'package:heart/core/env/home_widgets.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/utils/training_days.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// How many days back the training widget (#161) is told: its longest range
/// is thirteen weeks from a Monday, which starts at most 90 days ago.
const _span = 91;

/// Keeps the Home Screen's training widget (#161) told what it draws: the
/// signed-in user's finished workouts per day, the weight unit, and the
/// theme's accent. Told again whenever one of them changes, and only when
/// what it would be told changed.
///
/// Told whether or not a widget is on the Home Screen: the snapshot is a few
/// kilobytes on the device, and a widget the user has just added then draws
/// their training at once instead of waiting for the app to be opened. Adding
/// the widget is the opt-in (`docs/opt-in.md`); the app looks the same either
/// way.
class HomeWidgetsPresenter extends StatefulWidget {
  final Widget child;

  /// The platform's layer, or null where there is none (tests, the web).
  final HomeWidgets? widgets;

  const new({super.key, required this.child, this.widgets});

  @override
  State<HomeWidgetsPresenter> createState() => _HomeWidgetsPresenterState();
}

class _HomeWidgetsPresenterState extends State<HomeWidgetsPresenter> {
  Workouts? _workouts;
  Preferences? _preferences;
  AppTheme? _theme;
  Auth? _auth;

  /// What was last told, encoded, so the same snapshot is not sent again on
  /// every set ticked; null before the first.
  String? _published;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workouts = Workouts.of(context);
    if (!identical(workouts, _workouts)) {
      _workouts?.removeListener(_sync);
      _workouts = workouts..addListener(_sync);
    }
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_sync);
      _preferences = preferences..addListener(_sync);
    }
    final theme = AppTheme.of(context);
    if (!identical(theme, _theme)) {
      _theme?.removeListener(_sync);
      _theme = theme..addListener(_sync);
    }
    final auth = Auth.of(context);
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_sync);
      _auth = auth..addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    _workouts?.removeListener(_sync);
    _preferences?.removeListener(_sync);
    _theme?.removeListener(_sync);
    _auth?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _sync() {
    final widgets = widget.widgets;
    final workouts = _workouts;
    if (widgets == null || workouts == null) return;
    final user = _auth?.user;
    // before the history is read a launch knows of no workout, and the widget
    // keeps the last snapshot rather than flashing an empty one
    if (user != null && !workouts.historyInitialized) return;
    final snapshot = switch (user) {
      null => null,
      _ => _snapshot(workouts),
    };
    final encoded = switch (snapshot) {
      TrainingSnapshot snapshot => jsonEncode(snapshot.toMap()),
      null => '',
    };
    if (encoded == _published) return;
    _published = encoded;
    widgets.setTraining(snapshot);
  }

  TrainingSnapshot _snapshot(Workouts workouts) {
    final now = DateTime.now();
    final preset = (_theme ?? AppTheme.of(context)).preset;
    return TrainingSnapshot(
      days: trainingDays(workouts.history, since: DateTime(now.year, now.month, now.day - _span)),
      unit: _preferences?.weightUnit ?? .metric,
      accent: preset.light.accent.toARGB32(),
      accentDark: preset.dark.accent.toARGB32(),
    );
  }
}
