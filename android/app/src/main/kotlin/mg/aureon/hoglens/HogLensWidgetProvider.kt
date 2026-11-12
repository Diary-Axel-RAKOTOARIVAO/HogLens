package mg.aureon.hoglens

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import mg.aureon.hoglens.WidgetSupport.text

/** 3x2: visitors today, change versus yesterday, seven-day strip, week total. */
class HogLensWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            val d = WidgetSupport.scoped(widgetData, id)
            WidgetSupport.measure(appWidgetManager, id)
            val v = RemoteViews(context.packageName, R.layout.hoglens_widget)
            WidgetSupport.bind(v, context, d, R.id.widget_root, R.id.widget_title, R.id.widget_updated)
            v.setTextViewText(R.id.widget_visitors, text(d, "visitors"))
            v.setTextViewText(R.id.widget_caption, text(d, "l_visitors_today", "visitors today"))
            v.setTextViewText(R.id.widget_week, text(d, "week", ""))
            WidgetSupport.delta(v, d, R.id.widget_delta)
            WidgetSupport.bars(v, context, d, R.id.widget_bars)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
