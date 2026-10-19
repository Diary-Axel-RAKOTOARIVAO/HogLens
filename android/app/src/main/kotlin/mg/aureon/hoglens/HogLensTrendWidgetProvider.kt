package mg.aureon.hoglens

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import mg.aureon.hoglens.WidgetSupport.text

class HogLensTrendWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.hoglens_widget_trend)
            WidgetSupport.bind(v, context, widgetData, R.id.widget_root, R.id.widget_title, TrendBinding.updatedId)
            TrendBinding.fill(v, context, widgetData)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
