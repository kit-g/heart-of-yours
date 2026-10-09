package me.heart

import android.content.Context
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Locale
import kotlin.coroutines.resume

/// A second Flutter engine, headless, for the assistant's questions (#288,
/// #289): it runs `questionsMain` (lib/main.dart), which answers over the
/// `heart/questions` channel from the device's mirror in the device's
/// language. Started on the first question and kept while the process lives.
/// Never the app's own engine — a function runs with the app possibly not up.
object QuestionsEngine {
    private const val TAG = "HeartQuestions"
    private const val DEADLINE_MS = 15_000L
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null

    /// One question; the answer is a sentence in the device's language, or
    /// null when the engine could not answer.
    suspend fun ask(
        context: Context,
        question: String,
        userId: String?,
        exerciseId: String? = null,
        template: String? = null,
    ): String? = withContext(Dispatchers.Main) {
        val started = System.currentTimeMillis()
        val channel = start(context.applicationContext) ?: return@withContext null
        val arguments = buildMap<String, Any?> {
            put("question", question)
            put("locale", Locale.getDefault().toLanguageTag())
            if (userId != null) put("userId", userId)
            if (exerciseId != null) put("exerciseId", exerciseId)
            if (template != null) put("template", template)
        }
        // an engine that came up without its Dart side never answers; the
        // deadline is the assistant's patience
        val answer = withTimeoutOrNull(DEADLINE_MS) {
            suspendCancellableCoroutine<String?> { continuation ->
                channel.invokeMethod("ask", arguments, object : MethodChannel.Result {
                    override fun success(result: Any?) = continuation.resume(result as? String)

                    override fun error(code: String, message: String?, details: Any?) {
                        Log.w(TAG, "$question failed: $code $message")
                        continuation.resume(null)
                    }

                    override fun notImplemented() = continuation.resume(null)
                })
            }
        }
        Log.i(TAG, "$question answered in ${System.currentTimeMillis() - started} ms")
        answer
    }

    private fun start(context: Context): MethodChannel? {
        channel?.let { return it }
        return try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val engine = FlutterEngine(context)
            // by library, not by the root library: a build started from another
            // entrypoint has main.dart imported, not as its root
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "package:heart/main.dart", "questionsMain"),
            )
            GeneratedPluginRegistrant.registerWith(engine)
            MethodChannel(engine.dartExecutor.binaryMessenger, "heart/questions").also {
                this.engine = engine
                channel = it
            }
        } catch (error: Exception) {
            Log.e(TAG, "The questions engine did not start", error)
            null
        }
    }
}
