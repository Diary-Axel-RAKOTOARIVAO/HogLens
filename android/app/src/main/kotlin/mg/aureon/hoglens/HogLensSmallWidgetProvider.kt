package mg.aureon.hoglens

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import mg.aureon.hoglens.WidgetSupport.text

class HogLensSmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.hoglens_widget_small)
            WidgetSupport.bind(v, context, widgetData, R.id.widget_root, R.id.widget_title, SmallBinding.updatedId)
            SmallBinding.fill(v, widgetData)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
