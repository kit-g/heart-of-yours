import Foundation

/// Commands from a second actor — the watch (#183), the lock screen (#141) —
/// that no Dart was listening for: the message or the intent woke this
/// process with the engine down, or not listening yet. Kept in UserDefaults,
/// oldest first, until Dart takes them once the active workout is loaded;
/// each names the workout it is about, so one gone stale by then is dropped
/// there, not here.
struct CommandQueue {
    let key: String
    let defaults: UserDefaults

    init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    func keep(_ command: [String: Any]) {
        let kept = defaults.array(forKey: key) ?? []
        defaults.set(kept + [command], forKey: key)
    }

    /// Everything kept, oldest first; asking clears it.
    func take() -> [[String: Any]] {
        let kept = defaults.array(forKey: key) as? [[String: Any]] ?? []
        defaults.removeObject(forKey: key)
        return kept
    }
}
