package mg.aureon.hoglens

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import mg.aureon.hoglens.WidgetSupport.text

class HogLensLiveWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            val d = WidgetSupport.scoped(widgetData, id)
            WidgetSupport.measure(appWidgetManager, id)
            val v = RemoteViews(context.packageName, R.layout.hoglens_widget_live)
            WidgetSupport.bind(v, context, d, R.id.widget_root, R.id.widget_title, LiveBinding.updatedId, "/live")
            LiveBinding.fill(v, d)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
