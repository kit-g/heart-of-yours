import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features.dart';
import 'preferences.dart';

/// What the end of a rest sounds like while workout sounds are on (#169).
///
/// [file] is the sound's base name in both bundles — `ios/Runner/Sounds` and
/// Android's `res/raw` — where `scripts/sounds.py` writes it. The
/// notification plays the same file the app does, so the two never disagree.
/// [name] is the storage key and never changes once shipped.
enum RestSound {
  chime('rest_chime'),
  bell('rest_bell'),
  beeps('rest_beeps'),
  marimba('rest_marimba');

  final String file;

  new(this.file);

  static RestSound fromString(String? value) {
    return values.where((each) => each.name == value).firstOrNull ?? chime;
  }
}

/// How loud the app's own sounds are, as a share of the device's volume.
///
/// The device's volume and the silent switch still have the last word: this
/// only scales within them. [name] is the storage key.
enum SoundVolume {
  off(0),
  low(.3),
  normal(.65),
  high(1);

  final double gain;

  new(this.gain);

  static SoundVolume fromString(String? value) {
    return values.where((each) => each.name == value).firstOrNull ?? normal;
  }
}

/// The "rest complete" notification's sound for a rest scheduled now: null
/// is the system's own (the 1.9 behaviour, workout sounds off), [silentNotification]
/// none at all, and anything else a [RestSound.file].
typedef NotificationSound = String?;

/// [NotificationSound] for no sound: workout sounds on, at [SoundVolume.off].
const silentNotification = '';

/// Plays the sounds bundled with the app. The one platform boundary of
/// [WorkoutSounds].
abstract interface class SoundPlayer {
  /// Plays the bundled sound [file] at [volume], 0 to 1 of the device's.
  ///
  /// Mixed with whatever else is playing, which is ducked for as long as the
  /// sound lasts and not stopped; and not at all where the device has been
  /// told to be quiet — the silent switch, a silent ringer, Do Not Disturb.
  Future<void> play(String file, {required double volume});
}

/// The workout's sounds (#169): the end of a rest, a ticked set, a record.
///
/// All of it is the feature's. Off — never asked, declined, or switched off —
/// nothing here makes a sound, and the "rest complete" notification keeps the
/// system's ([restNotificationSound] is null). The choices are kept either way,
/// on this device: how loud a phone should be is a fact about the phone.
class WorkoutSounds with ChangeNotifier {
  static const _restSoundKey = 'workoutSounds.rest';
  static const _volumeKey = 'workoutSounds.volume';
  static const _setDoneKey = 'workoutSounds.setDone';
  static const _recordKey = 'workoutSounds.record';
  static const _feature = Feature.workoutSounds;

  final Preferences _preferences;

  /// Null where there is nothing to play through: tests, the web.
  final SoundPlayer? _player;

  /// Whether the app is on screen. A rest that runs out with the app away is
  /// the notification's to sound, and no moment to ask anything.
  final bool Function() _onScreen;

  SharedPreferences? _prefs;

  new({required this._preferences, this._player, bool Function()? onScreen}) : _onScreen = onScreen ?? _visible;

  static WorkoutSounds of(BuildContext context) {
    return Provider.of<WorkoutSounds>(context, listen: false);
  }

  static WorkoutSounds watch(BuildContext context) {
    return Provider.of<WorkoutSounds>(context, listen: true);
  }

  /// Inactive is still on screen: the shade or Control Center pulled over
  /// the app. Null is a binding that has not heard from the platform yet,
  /// which only happens before anything could have run out.
  static bool _visible() {
    return switch (WidgetsBinding.instance.lifecycleState) {
      .resumed || .inactive || null => true,
      .hidden || .paused || .detached => false,
    };
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    notifyListeners();
  }

  bool get _on => _preferences.isOn(_feature);

  RestSound get restSound => RestSound.fromString(_prefs?.getString(_restSoundKey));

  SoundVolume get volume => SoundVolume.fromString(_prefs?.getString(_volumeKey));

  /// A sound on every ticked set. Off until chosen: heard twenty times a
  /// workout, it is a sound to want, not one to find.
  bool get setDoneSound => _prefs?.getBool(_setDoneKey) ?? false;

  /// A sound on a personal record. Off until chosen, like [setDoneSound].
  bool get recordSound => _prefs?.getBool(_recordKey) ?? false;

  /// Picks the rest's sound, and plays it: choosing a sound is listening to it.
  void setRestSound(RestSound sound) {
    _prefs?.setString(_restSoundKey, sound.name);
    notifyListeners();
    _play(sound.file);
  }

  /// Sets the volume, and plays the rest's sound at it so the choice is heard.
  void setVolume(SoundVolume volume) {
    _prefs?.setString(_volumeKey, volume.name);
    notifyListeners();
    _play(restSound.file);
  }

  void setSetDoneSound({required bool on}) {
    _prefs?.setBool(_setDoneKey, on);
    notifyListeners();
    if (on) _play(_setDoneFile);
  }

  void setRecordSound({required bool on}) {
    _prefs?.setBool(_recordKey, on);
    notifyListeners();
    if (on) _play(_recordFile);
  }

  /// What the "rest complete" notification plays, for one scheduled now.
  NotificationSound get restNotificationSound {
    return switch ((_on, volume)) {
      (false, _) => null,
      (true, .off) => silentNotification,
      (true, .low || .normal || .high) => restSound.file,
    };
  }

  /// The exercise under which the one ask goes (`docs/opt-in.md`): the first
  /// whose rest ran out this session with the app on screen and the feature
  /// never asked about. It stays put for the session, with the offer or the
  /// notice after a no.
  String? get offerUnder => _offerUnder;
  String? _offerUnder;

  /// A rest of [exerciseId] ran out (`Alarms`). On screen, that is the rest
  /// sound — or, never asked, the moment to ask.
  void restRanOut(String exerciseId) {
    if (!_onScreen()) return;
    if (_on) return _play(restSound.file);
    if (_offerUnder == null && _preferences.isInitialized && _preferences.shouldOffer(_feature)) {
      _offerUnder = exerciseId;
      notifyListeners();
    }
  }

  /// A set was ticked in the app.
  void setDone() {
    if (_on && setDoneSound) _play(_setDoneFile);
  }

  /// A personal record was set. Nothing calls it yet: the hook the live
  /// record note (#160) sounds through when it lands.
  void record() {
    if (_on && recordSound) _play(_recordFile);
  }

  void _play(String file) {
    if (!_on || volume == .off) return;
    _player?.play(file, volume: volume.gain);
  }
}

/// `scripts/sounds.py`'s names for the two cues that are not the rest's.
const _setDoneFile = 'set_tick';
const _recordFile = 'record_fanfare';
