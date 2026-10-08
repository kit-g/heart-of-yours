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

        let answer: String? = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                channel.invokeMethod("ask", arguments: arguments) { result in
                    continuation.resume(returning: result as? String)
                }
            }
        }
        log.info("\(question, privacy: .public) answered in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
        return answer
    }

    @MainActor
    private func start() -> FlutterMethodChannel? {
        if let channel { return channel }
        let engine = FlutterEngine(name: "questions", project: nil, allowHeadlessExecution: true)
        guard engine.run(withEntrypoint: "questionsMain") else {
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
