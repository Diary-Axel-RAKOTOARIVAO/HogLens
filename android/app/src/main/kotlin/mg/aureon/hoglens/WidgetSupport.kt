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
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** Reads what HomeWidgetService wrote and fills the common views. */
object WidgetSupport {
    fun text(d: SharedPreferences, key: String, fallback: String = "—"): String =
        d.getString(key, null)?.takeIf { it.isNotEmpty() } ?: fallback

    /** Reads one widget instance's own project and range: its values live under `p_<project>_<range>_`. */
    fun scoped(d: SharedPreferences, id: Int): SharedPreferences {
        var pid = d.getString("cfg_${id}_project", null)
        var range = d.getString("cfg_${id}_range", null)
        if (pid == null) {
            // A widget pinned from the app adopts the project and range picked there.
            val pending = d.getString("pending_project", null)
            if (pending != null) {
                pid = pending
                range = d.getString("pending_range", null) ?: "today"
                d.edit().putString("cfg_${id}_project", pid).putString("cfg_${id}_range", range)
                    .remove("pending_project").remove("pending_range").apply()
            }
        }
        if (pid == null) return ScopedPrefs(d, "", null)
        return ScopedPrefs(d, "p_${pid}_${range ?: "today"}_", pid)
    }

    @Volatile private var widthDp = 300
    @Volatile private var heightDp = 150

    /** Remember the widget's current size so charts are drawn at the right aspect. */
    fun measure(manager: android.appwidget.AppWidgetManager, id: Int) {
        val o = manager.getAppWidgetOptions(id)
        val w = o.getInt(android.appwidget.AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = o.getInt(android.appwidget.AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        if (w > 0) widthDp = w
        if (h > 0) heightDp = h
    }

    private const val STALE_AFTER_MS = 90L * 60 * 1000

    fun bind(views: RemoteViews, context: Context, d: SharedPreferences, rootId: Int, titleId: Int?, updatedId: Int?, route: String = "") {
        val pid = d.getString("_pid", null)
        val uri = if (pid != null) Uri.parse("hoglens://widget/p/$pid$route") else null
        views.setOnClickPendingIntent(rootId, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri))
        views.setInt(R.id.widget_dot, "setColorFilter", accent(d))
        if (titleId != null) views.setTextViewText(titleId, text(d, "title", "HogLens"))
        if (updatedId != null) {
            val u = d.getString("updated", null)
            val at = d.getString("updatedAt", null)?.toLongOrNull()
            val stale = at != null && System.currentTimeMillis() - at > STALE_AFTER_MS
            views.setTextViewText(
                updatedId,
                when {
                    u == null -> ""
                    stale -> "↻ ${text(d, "l_stale", "Stale")} · $u"
                    else -> "↻ $u"
                },
            )
            views.setTextColor(updatedId, if (stale) Color.parseColor("#D97706") else context.getColor(R.color.widget_faint))
            // Tapping the timestamp refreshes this widget without opening the app.
            views.setOnClickPendingIntent(updatedId, HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("hoglens://widget/refresh")))
        }
    }

    /** Tinted pill like the Trends card in the app: green up, red down, neutral flat. */
    fun delta(views: RemoteViews, d: SharedPreferences, id: Int) {
        val delta = d.getString("delta", null) ?: ""
        views.setTextViewText(id, delta)
        views.setViewVisibility(id, if (delta.isEmpty()) View.GONE else View.VISIBLE)
        val sign = d.getInt("deltaSign", 0)
        views.setTextColor(
            id,
            when {
                sign > 0 -> Color.parseColor("#16A34A")
                sign < 0 -> Color.parseColor("#DC2626")
                else -> Color.parseColor("#8A8A8A")
            },
        )
        views.setInt(
            id,
            "setBackgroundResource",
            when {
                sign > 0 -> R.drawable.hoglens_pill_up
                sign < 0 -> R.drawable.hoglens_pill_down
                else -> R.drawable.hoglens_pill_flat
            },
        )
    }

    private fun values(d: SharedPreferences, key: String): List<Float> =
        (d.getString(key, null) ?: "").split(',').mapNotNull { it.trim().toFloatOrNull() }

    // Opaque ARGB values exceed Int.MAX_VALUE, so home_widget stores them as
    // a Long; read either form.
    fun accent(d: SharedPreferences): Int =
        when (val v = d.all["accent"]) {
            is Int -> v
            is Long -> v.toInt()
            else -> Color.parseColor("#FF6600")
        }

    /** Software-drawn bitmaps: no GPU, so they render on any device. */
    private fun density(context: Context) = context.resources.displayMetrics.density.coerceAtMost(2.5f)

    fun bars(views: RemoteViews, context: Context, d: SharedPreferences, id: Int, miniW: Int? = null, miniH: Int? = null) {
        val v = values(d, "barsData")
        if (v.isEmpty()) {
            views.setViewVisibility(id, View.INVISIBLE)
            return
        }
        val dp = density(context)
        val mini = miniW != null && miniH != null
        val w = ((miniW ?: (widthDp - 32).coerceAtLeast(80)) * dp).toInt()
        val h = ((miniH ?: (heightDp - 118).coerceAtLeast(40)) * dp).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val color = accent(d)
        val max = (v.maxOrNull() ?: 0f).takeIf { it > 0f } ?: 1f
        val gap = (if (mini) 3 else 6) * dp
        val barW = (w - gap * (v.size - 1)) / v.size
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        v.forEachIndexed { i, value ->
            paint.color = if (i == v.size - 1) color else (color and 0x00FFFFFF) or (0x40 shl 24)
            val barH = (if (mini) 5 else 6) * dp + (h - (if (mini) 5 else 6) * dp) * (value / max)
            val left = i * (barW + gap)
            val r = (if (mini) 3 else 6) * dp
            canvas.drawRoundRect(RectF(left, h - barH, left + barW, h.toFloat()), r, r, paint)
        }
        views.setImageViewBitmap(id, bmp)
        views.setViewVisibility(id, View.VISIBLE)
    }

    /** The project's logo, or its initials on the accent, with the app's rounded corners. */
    fun avatar(views: RemoteViews, context: Context, d: SharedPreferences, id: Int) {
        val dp = density(context)
        val size = (48 * dp).toInt()
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
        val radius = size * 0.28f
        val logo = d.getString("logo", null)?.takeIf { it.isNotEmpty() }?.let {
            try { android.graphics.BitmapFactory.decodeFile(it) } catch (_: Throwable) { null }
        }
        if (logo != null) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            val shader = android.graphics.BitmapShader(logo, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            val scale = maxOf(size / logo.width.toFloat(), size / logo.height.toFloat())
            shader.setLocalMatrix(android.graphics.Matrix().apply {
                setScale(scale, scale)
                postTranslate((size - logo.width * scale) / 2, (size - logo.height * scale) / 2)
            })
            paint.shader = shader
            canvas.drawRoundRect(rect, radius, radius, paint)
        } else {
            canvas.drawRoundRect(rect, radius, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent(d) })
            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = size * 0.38f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                textAlign = Paint.Align.CENTER
            }
            canvas.drawText(d.getString("initials", null) ?: "?", size / 2f, size / 2f - (text.descent() + text.ascent()) / 2, text)
        }
        views.setImageViewBitmap(id, bmp)
    }

    fun spark(views: RemoteViews, context: Context, d: SharedPreferences, id: Int) {
        val v = values(d, "sparkData")
        if (v.size < 2) {
            views.setViewVisibility(id, View.INVISIBLE)
            return
        }
        val dp = density(context)
        val w = ((widthDp - 32).coerceAtLeast(80) * dp).toInt()
        val h = ((heightDp - 175).coerceAtLeast(50) * dp).toInt()
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
            shader = LinearGradient(0f, 0f, 0f, h.toFloat(), (color and 0x00FFFFFF) or (0x4D shl 24), color and 0x00FFFFFF, Shader.TileMode.CLAMP)
        }
        canvas.drawPath(fill, fillPaint)
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = 2.5f * dp
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(line, linePaint)
        views.setImageViewBitmap(id, bmp)
        views.setViewVisibility(id, View.VISIBLE)
    }
}


/** Prefix-scoped read-only view of the widget preferences. */
class ScopedPrefs(private val base: SharedPreferences, private val prefix: String, private val pid: String?) : SharedPreferences by base {
    override fun getString(key: String, defValue: String?): String? =
        if (key == "_pid") pid else base.all[prefix + key]?.toString() ?: defValue

    override fun getInt(key: String, defValue: Int): Int =
        when (val v = base.all[prefix + key]) {
            is Int -> v
            is Long -> v.toInt()
            else -> defValue
        }

    override fun getAll(): MutableMap<String, *> {
        val out = HashMap<String, Any?>()
        for ((k, v) in base.all) if (k.startsWith(prefix)) out[k.removePrefix(prefix)] = v
        return out
    }
}
