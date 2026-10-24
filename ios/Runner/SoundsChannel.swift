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

    /// Whether [name] started; a sound not in the bundle, or a session that
    /// would not start, is false and nothing else.
    private func play(_ name: String, volume: Float) -> Bool {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return false }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.duckOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = max(0, min(1, volume))
            player.delegate = self
            playing.insert(player)
            return player.play()
        } catch {
            return false
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playing.remove(player)
        // the last one out lets the music back up
        guard playing.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
