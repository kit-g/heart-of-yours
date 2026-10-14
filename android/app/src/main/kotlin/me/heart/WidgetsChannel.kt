package me.heart

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// The app's half of the `heart/widgets` channel (#161): Dart publishes the
/// user's training per day, this keeps it for the training widget and
/// redraws the widgets on the Home Screen when it changed.
object WidgetsChannel {
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "heart/widgets").setMethodCallHandler { call, result ->
            when (call.method) {
                "setTraining" -> {
                    // null, or anything unreadable, is nobody's training: the
                    // widget draws empty rather than someone else's
                    if (TrainingSnapshot.write(TrainingSnapshot.prefs(app), call.arguments as? Map<*, *>)) {
                        TrainingWidget.updateAll(app)
                        // the Start and Goals widgets draw in its accent
                        StartWidget.updateAll(app)
                        GoalsWidget.updateAll(app)
                    }
                    result.success(null)
                }
                // the Goals widget (#368): null, or anything unreadable, is
                // nobody's goals
                "setGoals" -> {
                    if (GoalsWidget.write(GoalsWidget.prefs(app), call.arguments as? Map<*, *>)) {
                        GoalsWidget.updateAll(app)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
