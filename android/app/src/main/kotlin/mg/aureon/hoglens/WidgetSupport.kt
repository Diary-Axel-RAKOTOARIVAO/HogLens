package mg.aureon.hoglens

import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** Reads what HomeWidgetService wrote and fills the common views. */
object WidgetSupport {
    fun text(d: SharedPreferences, key: String, fallback: String = "—"): String =
        d.getString(key, null)?.takeIf { it.isNotEmpty() } ?: fallback

    fun bind(views: RemoteViews, context: Context, d: SharedPreferences, rootId: Int, titleId: Int?, updatedId: Int?) {
        views.setOnClickPendingIntent(rootId, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
        if (titleId != null) views.setTextViewText(titleId, text(d, "title", "HogLens"))
        if (updatedId != null) {
            val u = d.getString("updated", null)
            views.setTextViewText(updatedId, if (u == null) "" else "${text(d, "l_updated", "Updated")} $u")
        }
    }

    fun delta(views: RemoteViews, d: SharedPreferences, id: Int) {
        val delta = d.getString("delta", null) ?: ""
        views.setTextViewText(id, delta)
        views.setViewVisibility(id, if (delta.isEmpty()) View.GONE else View.VISIBLE)
        val sign = d.getInt("deltaSign", 0)
        views.setTextColor(
            id,
            when {
                sign > 0 -> Color.parseColor("#22C55E")
                sign < 0 -> Color.parseColor("#EF4444")
                else -> Color.parseColor("#6B6B6B")
            },
        )
    }

    fun image(views: RemoteViews, d: SharedPreferences, key: String, id: Int) {
        val path = d.getString(key, null)
        val bmp = if (path != null) BitmapFactory.decodeFile(path) else null
        if (bmp != null) {
            views.setImageViewBitmap(id, bmp)
            views.setViewVisibility(id, View.VISIBLE)
        } else {
            views.setViewVisibility(id, View.INVISIBLE)
        }
    }
}
