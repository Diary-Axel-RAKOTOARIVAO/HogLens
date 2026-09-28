package mg.aureon.hoglens

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Renders the values HomeWidgetService writes from Dart. */
class HogLensWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.hoglens_widget).apply {
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setTextViewText(R.id.widget_title, widgetData.getString("title", null) ?: "HogLens")
                setTextViewText(R.id.widget_visitors, widgetData.getString("visitors", null) ?: "—")
                setTextViewText(R.id.widget_week, widgetData.getString("week", null) ?: "Open the app to load")
                val delta = widgetData.getString("delta", null) ?: ""
                setTextViewText(R.id.widget_delta, delta)
                setViewVisibility(R.id.widget_delta, if (delta.isEmpty()) View.GONE else View.VISIBLE)
                val sign = widgetData.getInt("deltaSign", 0)
                setTextColor(
                    R.id.widget_delta,
                    when {
                        sign > 0 -> Color.parseColor("#22C55E")
                        sign < 0 -> Color.parseColor("#EF4444")
                        else -> Color.parseColor("#6B6B6B")
                    },
                )
                val updated = widgetData.getString("updated", null)
                setTextViewText(R.id.widget_updated, if (updated == null) "" else "Updated $updated")
                val bars = widgetData.getString("bars", null)
                if (bars != null) {
                    val bmp = BitmapFactory.decodeFile(bars)
                    if (bmp != null) {
                        setImageViewBitmap(R.id.widget_bars, bmp)
                        setViewVisibility(R.id.widget_bars, View.VISIBLE)
                    }
                } else {
                    setViewVisibility(R.id.widget_bars, View.INVISIBLE)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
