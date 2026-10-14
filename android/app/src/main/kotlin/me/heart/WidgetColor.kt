package me.heart

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.os.Build
import android.widget.RemoteViews
import androidx.annotation.ColorRes

/// A colour a widget is drawn in, light and dark (#382). From Android 12 the
/// launcher holds both and picks one itself when the phone switches modes,
/// with no redraw; before it, a widget keeps the one it was drawn in.
class WidgetColor private constructor(
    /// light, dark: the app's, as it last said
    private val pair: Pair<Int, Int>?,
    /// a resource's, which has its own night variant
    @param:ColorRes private val resource: Int,
) {
    /// Calls [method], which takes a colour int, on the view [id].
    fun set(context: Context, views: RemoteViews, id: Int, method: String) {
        when {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S -> views.setInt(id, method, current(context))
            pair == null -> views.setColor(id, method, resource)
            else -> views.setColorInt(id, method, pair.first, pair.second)
        }
    }

    /// Calls [method], which takes a ColorStateList, on the view [id]; a
    /// no-op before Android 12, which cannot.
    fun setList(views: RemoteViews, id: Int, method: String) {
        when {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S -> Unit
            pair == null -> views.setColorStateList(id, method, resource)
            else -> views.setColorStateList(id, method, ColorStateList.valueOf(pair.first), ColorStateList.valueOf(pair.second))
        }
    }

    /// The one for the mode the phone is in now.
    fun current(context: Context): Int {
        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        return when {
            pair == null -> context.getColor(resource)
            night -> pair.second
            else -> pair.first
        }
    }

    companion object {
        /// The theme's accent, as the app last said; [fallback] before it has.
        fun accent(snapshot: TrainingSnapshot?, @ColorRes fallback: Int) = when (snapshot) {
            null, TrainingSnapshot.EMPTY -> WidgetColor(null, fallback)
            else -> WidgetColor(snapshot.accent to snapshot.accentDark, fallback)
        }

        fun of(@ColorRes resource: Int) = WidgetColor(null, resource)
    }
}
