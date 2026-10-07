import 'dart:async';

import 'package:heart/core/env/shortcuts.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// How long a link waits for the state it needs — the active workout read from
/// the mirror, the templates read from it — before acting on what is known.
const _patience = Duration(seconds: 10);

/// The link being applied, while one is. A cold start's redirect is decided
/// more than once for the same location — the router is refreshed as the
/// session and the mirror land — and each decision would ask again: two
/// "cancel the current workout?" dialogs, one over the other. The same link
/// arriving while the first is still at work is the same ask, and is dropped.
ShortcutLink? _inFlight;

/// Applies a [ShortcutLink] (#284) the way the same tap in the app would.
///
/// Called from the router's redirect, which has already sent the app to the
/// workouts tab; this opens what the link asked for over it, once the state it
/// needs has landed. A link that launched the app arrives while `Workouts.init`
/// is still reading the mirror and before the templates have been read, so it
/// waits for both, bounded — and on a wait that runs out, acts on what is
/// there, which for a template not yet known is nothing: the workouts tab
/// underneath, with the templates on it, is the right answer anyway.
///
/// Reaching for a shortcut is the yes to the feature (`Feature.shortcuts`):
/// the first link turns it on. One switched off never gets here — the redirect
/// treats the link as one the app has no screen for.
///
/// Nothing is cancelled by a link on its own: `start` over an active workout
/// asks the question a template card asks (keep it, or cancel and start), and
/// whichever the user picks, the workout that is active afterwards is the one
/// on screen. [navigator] is the root navigator, whose context the dialogs and
/// the sheet are shown from.
Future<void> runShortcutLink(
  ShortcutLink link, {
  required Workouts workouts,
  required Templates templates,
  required Preferences preferences,
  required GlobalKey<NavigatorState> navigator,
}) async {
  if (_inFlight == link) return;
  _inFlight = link;
  try {
    await _apply(link, workouts: workouts, templates: templates, preferences: preferences, navigator: navigator);
  } finally {
    _inFlight = null;
  }
}

Future<void> _apply(
  ShortcutLink link, {
  required Workouts workouts,
  required Templates templates,
  required Preferences preferences,
  required GlobalKey<NavigatorState> navigator,
}) async {
  if (!preferences.isOn(.shortcuts)) {
    preferences.setFeature(.shortcuts, on: true);
  }

  // off the redirect's own turn, like the Live Activity's tap
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await _settled(workouts, () => workouts.hasResolvedActiveWorkout);
  if (link case StartWorkoutLink(templateId: String())) {
    await _settled(templates, () => templates.hasLoaded);
  }

  final context = navigator.currentContext;
  if (context == null || !context.mounted) return;
  final router = HeartRouter.of(context);

  switch (link) {
    case StartWorkoutLink(:final templateId):
      final template = switch (templateId) {
        String id => templates.lookup(id),
        null => null,
      };
      // a template this device does not have: the tab underneath lists the
      // ones it does
      if (templateId != null && template == null) return;

      await startWorkoutOverActive(
        context,
        () => switch (template) {
          Template template => workouts.startWorkout(
            source: templates.samples.contains(template) ? .sample : .template,
            template: template.toWorkout(),
            applyPinnedNotes: true,
          ),
          null => workouts.startWorkout(source: .blank, name: L.of(context).defaultWorkoutName()),
        },
      );
      // started, or kept: either way there is a workout to show
      if (!workouts.hasActiveWorkout) return;
      workouts.notifyOfActiveWorkout();
      await router.showActiveWorkout();
    case FinishWorkoutLink():
      if (workouts.activeWorkout == null) return;
      workouts.notifyOfActiveWorkout();
      // the sheet first, and the question over it
      await router.showActiveWorkout();
      if (!context.mounted) return;
      await showFinishWorkoutDialog(context, workouts);
  }
}

/// Completes once [done] holds, or once [_patience] has run out.
Future<void> _settled(ChangeNotifier notifier, bool Function() done) {
  if (done()) return Future.value();
  final settled = Completer<void>();
  void check() {
    if (!done() || settled.isCompleted) return;
    notifier.removeListener(check);
    settled.complete();
  }

  notifier.addListener(check);
  return settled.future.timeout(_patience, onTimeout: () => notifier.removeListener(check));
}
