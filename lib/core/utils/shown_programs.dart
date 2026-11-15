import 'package:flutter/widgets.dart';
import 'package:heart_state/heart_state.dart';

/// The programs as a widget may show them (#593): every one with Programs on,
/// and with it off a coach's under Your coach ([Preferences.programShown]).
ShownPrograms shownPrograms(BuildContext context, {bool listen = false}) {
  final preferences = Provider.of<Preferences>(context, listen: listen);
  return Provider.of<Programs>(context, listen: listen).shown(preferences.programShown);
}

/// [Preferences.programShown] for the program [programId] names: false for
/// none, and the programs read only with Programs off.
bool programIdShown(BuildContext context, String? programId, {bool listen = false}) {
  final preferences = Provider.of<Preferences>(context, listen: listen);
  return switch (programId) {
    null => false,
    _ when preferences.isOn(.programs) => true,
    final String id => preferences.programShown(Provider.of<Programs>(context, listen: listen).lookup(id)),
  };
}

/// Whether what a program plans shows in a workout of [programId] — its
/// rests, its supplemental sets, its constraint: always with Programs on, and
/// with it off in a session of a coach's program (#593). Asked of the workout
/// on screen, never of the active one: a template's editor is not the session
/// under way.
bool planShown(BuildContext context, String? programId, {bool listen = false}) {
  if (Provider.of<Preferences>(context, listen: listen).isOn(.programs)) return true;
  return programIdShown(context, programId, listen: listen);
}
