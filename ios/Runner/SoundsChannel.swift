import AVFoundation
import Flutter

/// The app's half of the `heart/sounds` channel (#169): plays one of the
/// sounds in `Sounds/`, the files the rest's notification plays too.
///
/// The `ambient` category is what makes the silent switch silence it, and
/// `duckOthers` lowers the user's music for the moment it lasts instead of
/// stopping it. Ducking holds for as long as the session is active, so the
/// session is let go once the sound is done, with `notifyOthersOnDeactivation`
/// so the music comes back up.
final class SoundsChannel: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundsChannel()

    /// The players still sounding: an `AVAudioPlayer` stops when released.
    private var playing: Set<AVAudioPlayer> = []

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "heart/sounds", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "play":
                guard let self,
                      let arguments = call.arguments as? [String: Any],
                      let name = arguments["name"] as? String,
                      let volume = (arguments["volume"] as? NSNumber)?.floatValue
                else {
                    result(FlutterError(code: "bad_arguments", message: "play needs a name and a volume", details: nil))
                    return
                }
                result(self.play(name, volume: volume))
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// Whether the session has its category yet: set once, not on every tick.
    private var configured = false

    /// Whether [name] started; a sound not in the bundle, or a session that
    /// would not start, is false and nothing else.
    private func play(_ name: String, volume: Float) -> Bool {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return false }
        // a player a call, Siri or an alarm cut short never reports finishing:
        // left in, the session would never be let go and the music stay ducked
        playing = playing.filter(\.isPlaying)
        do {
            let session = AVAudioSession.sharedInstance()
            if !configured {
                try session.setCategory(.ambient, options: [.duckOthers])
                configured = true
            }
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = max(0, min(1, volume))
            player.delegate = self
            guard player.play() else {
                release()
                return false
            }
            playing.insert(player)
            return true
        } catch {
            release()
            return false
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playing.remove(player)
        release()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        playing.remove(player)
        release()
    }

    /// The last one out lets the music back up. A session that will not let
    /// go now is tried again after the next sound.
    private func release() {
        playing = playing.filter(\.isPlaying)
        guard playing.isEmpty else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // the category may have been taken from under us: set it again next time
            configured = false
        }
    }
}
