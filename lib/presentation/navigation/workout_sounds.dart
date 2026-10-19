import 'package:heart/core/env/notifications.dart';
import 'package:heart/presentation/widgets/feature_copy.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the rest's notification in step with workout sounds (#169), for the
/// whole app.
///
/// - The sound the notification plays is left where every surface that
///   schedules it can read it — the app, the ongoing notification's buttons,
///   the Live Activity and Siri ([publishRestTone]) — whenever the choice or
///   the switch changes.
/// - On Android, while the app is on screen, the notification goes up silent
///   and the app plays the end of the rest itself, at the volume chosen
///   ([quietRestNotification]); iOS does the same per notification.
///
/// Off, nothing is published, and the notification keeps the system's sound.
class WorkoutSoundsPresenter extends StatefulWidget {
  /// False where the notifications plugin never started: tests, the web.
  final bool enabled;
  final Widget child;

  const new({super.key, required this.enabled, required this.child});

  @override
  State<WorkoutSoundsPresenter> createState() => _WorkoutSoundsPresenterState();
}

class _WorkoutSoundsPresenterState extends State<WorkoutSoundsPresenter> with WidgetsBindingObserver {
  WorkoutSounds? _sounds;
  Preferences? _preferences;

  /// What was last published; a record, so an unchanged tone compares equal
  /// and costs no write.
  RestTone? _published;
  bool _hasPublished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sounds = WorkoutSounds.of(context);
    if (!identical(sounds, _sounds)) {
      _sounds?.removeListener(_publish);
      _sounds = sounds..addListener(_publish);
    }
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_publish);
      _preferences = preferences..addListener(_publish);
    }
    // the channel's name is copy: a new language names it again
    _publish();
    // the app starts on screen, before any change of state says so
    _quiet(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _quiet(state);

  void _quiet(AppLifecycleState? state) {
    if (!widget.enabled || Theme.of(context).platform != .android) return;
    quietRestNotification(
      quiet: switch (state) {
        .resumed || .inactive || null => true,
        .hidden || .paused || .detached => false,
      },
    );
  }

  void _publish() {
    final sounds = _sounds;
    if (!widget.enabled || !mounted || sounds == null || !(_preferences?.isInitialized ?? false)) return;
    final l = L.of(context);
    final tone = switch (sounds.restNotificationSound) {
      null => null,
      silentNotification => (sound: silentNotification, channel: l.restSilentChannel),
      final String file => (sound: file, channel: l.restSoundChannel(sounds.restSound.title(l))),
    };
    if (_hasPublished && tone == _published) return;
    _hasPublished = true;
    _published = tone;
    publishRestTone(tone);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sounds?.removeListener(_publish);
    _preferences?.removeListener(_publish);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
