package mg.aureon.hoglens

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import mg.aureon.hoglens.WidgetSupport.text

/** 4x1: the project card from the app's home screen. */
class HogLensProjectWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            val d = WidgetSupport.scoped(widgetData, id)
            val v = RemoteViews(context.packageName, R.layout.hoglens_widget_project)
            WidgetSupport.bind(v, context, d, R.id.widget_root, R.id.widget_title, null)
            WidgetSupport.avatar(v, context, d, R.id.widget_avatar)
            v.setTextViewText(R.id.widget_host, text(d, "host", "PostHog"))
            v.setTextViewText(R.id.widget_pid, text(d, "pid", "#"))
            v.setTextViewText(R.id.widget_visitors, text(d, "visitors"))
            v.setTextViewText(R.id.widget_caption, text(d, "l_visitors_today", "visitors today"))
            WidgetSupport.bars(v, context, d, R.id.widget_bars, 88, 18)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
