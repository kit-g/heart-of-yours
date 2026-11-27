import 'package:flutter/services.dart';
import 'package:heart_state/heart_state.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Sounds');

/// The workout sounds' player (#169): the native half of the `heart/sounds`
/// channel plays a sound bundled with the app — the files
/// `scripts/sounds.py` writes, the same ones the rest's notification plays.
///
/// Native rather than a plugin because what matters is how a sound behaves
/// beside everything else, which is platform policy:
///
/// - **iOS**: the `ambient` audio session, so the silent switch silences it,
///   with `duckOthers`, so music dips for the moment it lasts instead of
///   stopping; the session is let go afterwards, so the music comes back up.
/// - **Android**: the notification stream, so a silent or vibrating ringer
///   and Do Not Disturb silence it the way they do a notification, with a
///   transient focus request that may duck, given back when it is done.
class ChannelSoundPlayer implements SoundPlayer {
  static const _channel = MethodChannel('heart/sounds');

  const new();

  @override
  Future<void> play(String file, {required double volume}) async {
    try {
      await _channel.invokeMethod<void>('play', {'name': file, 'volume': volume});
    } on MissingPluginException {
      // a host without the channel: a widget test, the web
    } on PlatformException catch (e, stacktrace) {
      // a sound that will not play is not worth more than a line in the log
      _logger.warning('Could not play $file', e, stacktrace);
    }
  }
}
