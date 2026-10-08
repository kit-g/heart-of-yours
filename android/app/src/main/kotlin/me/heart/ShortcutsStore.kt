package me.heart

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/// What Dart publishes for the assistant layer, kept where the parts of the
/// app that run without Dart — the launcher's shortcuts (#286), the App
/// Functions (#289) — can read it: the templates and exercises by id and
/// localized name, the rest the user is on, the set up next, and whose
/// training it all is. Each is the JSON of what came over `heart/shortcuts`,
/// or absent, which is what the feature switched off publishes.
object ShortcutsStore {
    private const val FILE = "heart.shortcuts"
    const val TEMPLATES = "templates"
    const val EXERCISES = "exercises"
    const val REST = "rest"
    const val NEXT_SET = "nextSet"
    const val USER_ID = "userId"

    fun prefs(context: Context): SharedPreferences = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    /// Keeps [value] — a map, a list, a string — as JSON, or forgets the key.
    fun put(prefs: SharedPreferences, key: String, value: Any?) {
        val encoded = when (value) {
            null -> null
            is Map<*, *> -> JSONObject(value).toString()
            is List<*> -> JSONArray(value).toString()
            else -> value.toString()
        }
        prefs.edit().apply {
            if (encoded == null) remove(key) else putString(key, encoded)
        }.apply()
    }

    fun string(prefs: SharedPreferences, key: String): String? = prefs.getString(key, null)

    fun obj(prefs: SharedPreferences, key: String): JSONObject? = runCatching { JSONObject(prefs.getString(key, null) ?: return null) }.getOrNull()

    fun array(prefs: SharedPreferences, key: String): JSONArray? = runCatching { JSONArray(prefs.getString(key, null) ?: return null) }.getOrNull()
}

/// Names the assistant says, matched to what Dart published: "bench press"
/// finds "Bench Press (Barbell)" — by whole name first, then by a name that
/// contains the words, case and accents aside.
object NameLookup {
    /// The `id` of the entry of [list] whose `name` matches [spoken], or null.
    fun id(list: JSONArray?, spoken: String): String? {
        if (list == null) return null
        val wanted = fold(spoken)
        if (wanted.isEmpty()) return null
        val entries = (0 until list.length()).mapNotNull { list.optJSONObject(it) }
        val exact = entries.firstOrNull { fold(it.optString("name")) == wanted }
        val loose = exact ?: entries.firstOrNull { fold(it.optString("name")).contains(wanted) }
        return loose?.optString("id")?.takeIf { it.isNotEmpty() }
    }

    fun fold(name: String): String {
        return java.text.Normalizer.normalize(name, java.text.Normalizer.Form.NFD)
            .replace(Regex("\\p{M}+"), "")
            .lowercase()
            .trim()
    }
}
