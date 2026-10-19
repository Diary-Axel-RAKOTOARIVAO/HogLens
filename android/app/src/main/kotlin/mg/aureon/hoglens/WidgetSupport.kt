package mg.aureon.hoglens

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
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

    private fun values(d: SharedPreferences, key: String): List<Float> =
        (d.getString(key, null) ?: "").split(',').mapNotNull { it.trim().toFloatOrNull() }

    // Opaque ARGB values exceed Int.MAX_VALUE, so home_widget stores them as
    // a Long; read either form.
    private fun accent(d: SharedPreferences): Int =
        when (val v = d.all["accent"]) {
            is Int -> v
            is Long -> v.toInt()
            else -> Color.parseColor("#FF6600")
        }

    /** Software-drawn bitmaps: no GPU, so they render on any device. */
    private fun density(context: Context) = context.resources.displayMetrics.density.coerceAtMost(2.5f)

    fun bars(views: RemoteViews, context: Context, d: SharedPreferences, id: Int) {
        val v = values(d, "barsData")
        if (v.isEmpty()) {
            views.setViewVisibility(id, View.INVISIBLE)
            return
        }
        val dp = density(context)
        val w = (140 * dp).toInt()
        val h = (36 * dp).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val color = accent(d)
        val max = (v.maxOrNull() ?: 0f).takeIf { it > 0f } ?: 1f
        val gap = 4 * dp
        val barW = (w - gap * (v.size - 1)) / v.size
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        v.forEachIndexed { i, value ->
            paint.color = if (i == v.size - 1) color else (color and 0x00FFFFFF) or (0x4D shl 24)
            val barH = 4 * dp + (h - 4 * dp) * (value / max)
            val left = i * (barW + gap)
            canvas.drawRoundRect(RectF(left, h - barH, left + barW, h.toFloat()), 4 * dp, 4 * dp, paint)
        }
        views.setImageViewBitmap(id, bmp)
        views.setViewVisibility(id, View.VISIBLE)
    }

    fun spark(views: RemoteViews, context: Context, d: SharedPreferences, id: Int) {
        val v = values(d, "sparkData")
        if (v.size < 2) {
            views.setViewVisibility(id, View.INVISIBLE)
            return
        }
        val dp = density(context)
        val w = (300 * dp).toInt()
        val h = (70 * dp).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val color = accent(d)
        val max = (v.maxOrNull() ?: 0f).takeIf { it > 0f } ?: 1f
        fun x(i: Int) = w * i.toFloat() / (v.size - 1)
        fun y(i: Int) = h - 4 * dp - (h - 8 * dp) * (v[i] / max)
        val line = Path().apply {
            moveTo(x(0), y(0))
            for (i in 1 until v.size) {
                val mid = (x(i - 1) + x(i)) / 2
                cubicTo(mid, y(i - 1), mid, y(i), x(i), y(i))
            }
        }
        val fill = Path(line).apply {
            lineTo(w.toFloat(), h.toFloat())
            lineTo(0f, h.toFloat())
            close()
        }
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(0f, 0f, 0f, h.toFloat(), (color and 0x00FFFFFF) or (0x59 shl 24), color and 0x00FFFFFF, Shader.TileMode.CLAMP)
        }
        canvas.drawPath(fill, fillPaint)
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = 2 * dp
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(line, linePaint)
        views.setImageViewBitmap(id, bmp)
        views.setViewVisibility(id, View.VISIBLE)
    }
}
