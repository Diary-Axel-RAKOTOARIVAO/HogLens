package mg.aureon.hoglens

import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import mg.aureon.hoglens.WidgetSupport.text

object SmallBinding {
    val updatedId: Int? = null
    fun fill(v: RemoteViews, d: SharedPreferences) {
        v.setTextViewText(R.id.widget_visitors, text(d, "visitors"))
        v.setTextViewText(R.id.widget_caption, text(d, "l_visitors_today", "visitors today"))
    }
}

object LiveBinding {
    val updatedId: Int? = R.id.widget_updated
    fun fill(v: RemoteViews, d: SharedPreferences) {
        v.setTextViewText(R.id.widget_live_label, text(d, "l_live", "LIVE"))
        v.setTextViewText(R.id.widget_live, text(d, "live"))
        v.setTextViewText(R.id.widget_caption, text(d, "l_on_site", "on site now"))
    }
}

object ErrorsBinding {
    val updatedId: Int? = R.id.widget_updated
    fun fill(v: RemoteViews, d: SharedPreferences) {
        val n = text(d, "errors")
        v.setTextViewText(R.id.widget_errors, n)
        // Red when something is throwing, green when all is quiet.
        v.setTextColor(R.id.widget_errors, android.graphics.Color.parseColor(if (n == "0") "#16A34A" else "#E5484D"))
        v.setTextViewText(R.id.widget_caption, text(d, "l_errors_today", "errors today"))
        v.setTextViewText(R.id.widget_top_error, text(d, "topError", ""))
    }
}

object OverviewBinding {
    val updatedId: Int? = R.id.widget_updated
    fun fill(v: RemoteViews, d: SharedPreferences) {
        v.setTextViewText(R.id.widget_visitors, text(d, "visitors"))
        v.setTextViewText(R.id.widget_caption, text(d, "l_visitors_today", "visitors today"))
        WidgetSupport.delta(v, d, R.id.widget_delta)
        v.setTextViewText(R.id.stat2_value, text(d, "views"))
        v.setTextViewText(R.id.stat2_label, text(d, "l_views", "Views"))
        v.setTextViewText(R.id.stat3_value, text(d, "sessions"))
        v.setTextViewText(R.id.stat3_label, text(d, "l_sessions", "Sessions"))
        v.setTextViewText(R.id.stat4_value, text(d, "live"))
        v.setTextViewText(R.id.stat4_label, text(d, "l_live", "LIVE"))
    }
}

object TrendBinding {
    val updatedId: Int? = R.id.widget_updated
    fun fill(v: RemoteViews, context: Context, d: SharedPreferences) {
        v.setTextViewText(R.id.widget_visitors, text(d, "visitors"))
        v.setTextViewText(R.id.widget_caption, text(d, "l_visitors_today", "visitors today"))
        WidgetSupport.delta(v, d, R.id.widget_delta)
        WidgetSupport.spark(v, context, d, R.id.widget_spark)
        v.setTextViewText(R.id.stat2_value, text(d, "views"))
        v.setTextViewText(R.id.stat2_label, text(d, "l_views", "Views"))
        v.setTextViewText(R.id.stat3_value, text(d, "sessions"))
        v.setTextViewText(R.id.stat3_label, text(d, "l_sessions", "Sessions"))
        v.setTextViewText(R.id.stat4_value, text(d, "errors"))
        v.setTextViewText(R.id.stat4_label, text(d, "l_errors_today", "errors today"))
    }
}
