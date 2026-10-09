import Flutter
import Foundation
import os

/// A second Flutter engine, headless, for the assistant's questions (#288):
/// it runs `questionsMain` (lib/main.dart), which answers over the
/// `heart/questions` channel from the device's mirror in the device's
/// language. Started on the first question and kept while the process
/// lives, so the second question pays no engine start. Never the app's own
/// engine — an intent runs with the app possibly not up at all.
final class QuestionsEngine {
    static let shared = QuestionsEngine()

    private let log = Logger(subsystem: "me.heart-of", category: "Questions")
    private var engine: FlutterEngine?
    private var channel: FlutterMethodChannel?

    /// Asks one question; the answer is a sentence, already in the device's
    /// language, or nil when the engine could not answer.
    func ask(_ question: String, exerciseId: String? = nil, template: String? = nil, userId: String?) async -> String? {
        let started = Date()
        guard let channel = await start() else { return nil }
        var arguments: [String: Any] = [
            "question": question,
            "locale": Locale.preferredLanguages.first ?? Locale.current.identifier,
        ]
        if let userId { arguments["userId"] = userId }
        if let exerciseId { arguments["exerciseId"] = exerciseId }
        if let template { arguments["template"] = template }

        // One resume, whatever comes first: the answer, or the deadline — an
        // engine that came up without its Dart side never answers, and a
        // continuation left hanging is Siri hanging.
        let answer: String? = await withCheckedContinuation { continuation in
            let once = Once()
            DispatchQueue.main.async {
                channel.invokeMethod("ask", arguments: arguments) { result in
                    once.run { continuation.resume(returning: result as? String) }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.deadline) {
                    once.run {
                        self.log.error("\(question, privacy: .public) was not answered in \(Self.deadline) s")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        log.info("\(question, privacy: .public) answered in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
        return answer
    }

    private static let deadline: TimeInterval = 15

    /// A gate that lets one of two racing closures through.
    private final class Once {
        private var done = false
        private let lock = NSLock()

        func run(_ body: () -> Void) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            body()
        }
    }

    @MainActor
    private func start() -> FlutterMethodChannel? {
        if let channel { return channel }
        let engine = FlutterEngine(name: "questions", project: nil, allowHeadlessExecution: true)
        // by library, not by the root library: a build started from another
        // entrypoint (the driver's main_driver.dart) has main.dart imported,
        // not as its root, and the lookup would miss
        guard engine.run(withEntrypoint: "questionsMain", libraryURI: "package:heart/main.dart") else {
            log.error("The questions engine did not start")
            return nil
        }
        GeneratedPluginRegistrant.register(with: engine)
        let channel = FlutterMethodChannel(name: "heart/questions", binaryMessenger: engine.binaryMessenger)
        self.engine = engine
        self.channel = channel
        return channel
    }
}
