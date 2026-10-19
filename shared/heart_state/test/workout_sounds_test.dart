import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/heart_state.dart';

class _Player implements SoundPlayer {
  final played = <(String, double)>[];

  @override
  Future<void> play(String file, {required double volume}) async => played.add((file, volume));
}

void main() {
  late Preferences preferences;
  late _Player player;
  late WorkoutSounds sut;
  var onScreen = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    onScreen = true;
    preferences = Preferences();
    await preferences.init();
    player = _Player();
    sut = WorkoutSounds(preferences: preferences, player: player, onScreen: () => onScreen);
    await sut.init();
  });

  tearDown(() {
    sut.dispose();
    preferences.dispose();
  });

  group('off', () {
    test('nothing sounds, and the notification keeps the system sound', () {
      sut.restRanOut('bench');
      sut.setDone();
      sut.record();
      sut.setRestSound(.bell);
      sut.setVolume(.high);
      expect(player.played, isEmpty);
      expect(sut.restNotificationSound, isNull);
    });

    test('switched off after being on, the choices stay and the notification is the system\'s again', () {
      preferences.setFeature(.workoutSounds, on: true);
      sut.setRestSound(.marimba);
      sut.setVolume(.low);
      preferences.setFeature(.workoutSounds, on: false);
      expect(sut.restSound, RestSound.marimba);
      expect(sut.volume, SoundVolume.low);
      expect(sut.restNotificationSound, isNull);
    });
  });

  group('the ask', () {
    test('goes under the first exercise whose rest ran out on screen, and stays there', () {
      onScreen = false;
      sut.restRanOut('bench');
      expect(sut.offerUnder, isNull, reason: 'a rest that ends with the app away is no moment to ask');

      onScreen = true;
      sut.restRanOut('squat');
      sut.restRanOut('row');
      expect(sut.offerUnder, 'squat');
      expect(player.played, isEmpty, reason: 'asking is not yet a yes');
    });

    test('is never made once answered', () {
      preferences.setFeature(.workoutSounds, on: false);
      sut.restRanOut('bench');
      expect(sut.offerUnder, isNull);
    });
  });

  group('on', () {
    setUp(() => preferences.setFeature(.workoutSounds, on: true));

    test('a rest that runs out on screen plays the chosen sound at the chosen volume', () {
      sut.setRestSound(.bell);
      sut.setVolume(.low);
      player.played.clear();

      sut.restRanOut('bench');
      onScreen = false;
      sut.restRanOut('bench');

      expect(player.played, [('rest_bell', SoundVolume.low.gain)]);
    });

    test('choosing a sound or a volume plays it, so the choice is heard', () {
      sut.setRestSound(.beeps);
      sut.setVolume(.high);
      expect(player.played, [('rest_beeps', SoundVolume.normal.gain), ('rest_beeps', 1.0)]);
    });

    test('at off, nothing plays and the notification is silent', () {
      sut.setVolume(.off);
      sut.restRanOut('bench');
      sut.setSetDoneSound(on: true);
      sut.setDone();
      expect(player.played, isEmpty);
      expect(sut.restNotificationSound, silentNotification);
    });

    test('the notification plays the file the app does', () {
      sut.setRestSound(.marimba);
      expect(sut.restNotificationSound, RestSound.marimba.file);
    });

    test('a ticked set and a record sound only once chosen', () {
      sut.setDone();
      sut.record();
      expect(player.played, isEmpty, reason: 'both are off until chosen');

      sut.setSetDoneSound(on: true);
      sut.setRecordSound(on: true);
      player.played.clear();
      sut.setDone();
      sut.record();
      expect(player.played.map((each) => each.$1), ['set_tick', 'record_fanfare']);
    });
  });

  test('storage keys are pinned', () {
    expect(RestSound.values.map((each) => each.name), ['chime', 'bell', 'beeps', 'marimba']);
    expect(SoundVolume.values.map((each) => each.name), ['off', 'low', 'normal', 'high']);
    expect(RestSound.fromString('gone'), RestSound.chime);
    expect(SoundVolume.fromString(null), SoundVolume.normal);
  });
}
