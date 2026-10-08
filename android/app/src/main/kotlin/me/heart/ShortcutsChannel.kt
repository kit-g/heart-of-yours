package me.heart

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// The launcher's per-template shortcuts (#286), and the store the App
/// Functions read (#289): the app's half of the `heart/shortcuts` channel, the
/// same one iOS answers. Dart publishes the
/// templates it can name — the user's own, then the samples — and this turns
/// them into dynamic shortcuts that open the app on `heart://app/start?template=…`
/// (#284). Replaced wholesale on every change; an empty list, which the
/// feature switched off publishes, clears them.
///
/// The static "Start a workout" shortcut lives in `res/xml/shortcuts.xml` and
/// counts against the launcher's limit, so one fewer template fits than the
/// limit says.
object ShortcutsChannel {
    private const val TAG = "HeartShortcuts"
    private const val STATIC_SHORTCUTS = 1

    fun register(context: Context, messenger: BinaryMessenger) {
        val store = ShortcutsStore.prefs(context.applicationContext)
        MethodChannel(messenger, "heart/shortcuts").setMethodCallHandler { call, result ->
            when (call.method) {
                "setTemplates" -> {
                    val list = call.arguments as? List<*>
                    if (list == null) {
                        result.error("bad_arguments", "setTemplates needs a list", null)
                    } else {
                        setTemplates(context.applicationContext, list)
                        ShortcutsStore.put(store, ShortcutsStore.TEMPLATES, list)
                        result.success(null)
                    }
                }
                // what the App Functions act on (#289): kept as published
                "setExercises" -> {
                    val list = call.arguments as? List<*>
                    if (list == null) {
                        result.error("bad_arguments", "setExercises needs a list", null)
                    } else {
                        ShortcutsStore.put(store, ShortcutsStore.EXERCISES, list)
                        result.success(null)
                    }
                }
                "setRest" -> {
                    ShortcutsStore.put(store, ShortcutsStore.REST, call.arguments as? Map<*, *>)
                    result.success(null)
                }
                "setNextSet" -> {
                    ShortcutsStore.put(store, ShortcutsStore.NEXT_SET, call.arguments as? Map<*, *>)
                    result.success(null)
                }
                "setSession" -> {
                    ShortcutsStore.put(store, ShortcutsStore.USER_ID, call.arguments as? String)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setTemplates(context: Context, list: List<*>) {
        val room = (ShortcutManagerCompat.getMaxShortcutCountPerActivity(context) - STATIC_SHORTCUTS).coerceAtLeast(0)
        val shortcuts = list.asSequence()
            .mapNotNull { entry ->
                val map = entry as? Map<*, *> ?: return@mapNotNull null
                val id = map["id"] as? String ?: return@mapNotNull null
                val name = map["name"] as? String ?: return@mapNotNull null
                shortcut(context, id, name)
            }
            .take(room)
            .toList()
        try {
            if (shortcuts.isEmpty()) {
                ShortcutManagerCompat.removeAllDynamicShortcuts(context)
            } else {
                ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts)
            }
        } catch (error: Exception) {
            // a launcher that refuses is never the app's problem
            Log.w(TAG, "Could not set template shortcuts", error)
        }
    }

    private fun shortcut(context: Context, id: String, name: String): ShortcutInfoCompat {
        val link = Uri.parse("heart://app/start").buildUpon().appendQueryParameter("template", id).build()
        val intent = Intent(Intent.ACTION_VIEW, link, context, MainActivity::class.java)
        return ShortcutInfoCompat.Builder(context, "template:$id")
            .setShortLabel(name)
            .setLongLabel(name)
            .setIcon(IconCompat.createWithResource(context, R.mipmap.ic_launcher))
            .setIntent(intent)
            .build()
    }
}
