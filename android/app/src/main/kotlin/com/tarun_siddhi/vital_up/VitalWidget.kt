package com.tarun_siddhi.vital_up

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Base for every VitalUp home screen widget.
 *
 * The app (lib/features/home_widget) formats all text and colours and saves
 * them with home_widget; widgets only lay them out, so the in-app preview and
 * the home screen always show the same thing. This class handles sizing
 * (exact size mappings on Android 12+, the reported size below that), the
 * "Updating" state for buttons that run Dart in the background, and asking
 * Dart to refresh when the saved data is from an earlier day or old.
 */
abstract class VitalWidgetProvider : HomeWidgetProvider() {

    /** Builds the widget for a [widthDp] x [heightDp] cell area. */
    abstract fun build(context: Context, data: SharedPreferences, widthDp: Int, heightDp: Int): RemoteViews

    /** Sizes (dp) that need a different layout; Android 12+ picks the best fit. */
    abstract val breakpoints: List<Pair<Int, Int>>

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id, widgetData)
        Wg.maybeAutoRefresh(context, widgetData)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int, data: SharedPreferences) {
        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            RemoteViews(
                breakpoints.associate { (w, h) ->
                    SizeF(w.toFloat(), h.toFloat()) to build(context, data, w, h)
                },
            )
        } else {
            val options = manager.getAppWidgetOptions(id)
            // Portrait: width is the min width, height the max height.
            val w = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, breakpoints.first().first)
            val h = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, breakpoints.first().second)
            build(context, data, w, h)
        }
        manager.updateAppWidget(id, views)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Wg.ACTION_BACKGROUND && intent.data != null) {
            Wg.markRefreshing(context)
            showUpdating(context)
            Wg.runInDart(context, intent.data!!)
            // If Dart never answers (process killed), redraw once the refreshing
            // flag has expired so the spinner goes away.
            Handler(Looper.getMainLooper()).postDelayed({ refreshAll(context) }, 21_000L)
            return
        }
        super.onReceive(context, intent)
    }

    private fun showUpdating(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))
        for (id in ids) {
            val views = RemoteViews(context.packageName, layoutForPartialUpdate()).apply {
                Wg.showRefreshing(this, true)
            }
            manager.partiallyUpdateAppWidget(id, views)
        }
    }

    /** Any layout of this widget that has the header (for the "Updating" label). */
    open fun layoutForPartialUpdate(): Int = R.layout.wg_metrics_row

    private fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))
        val data = HomeWidgetPlugin.getData(context)
        for (id in ids) render(context, manager, id, data)
    }
}

/** Shared widget helpers: data keys, intents, header and metric binding. */
object Wg {
    const val ACTION_BACKGROUND = "com.tarun_siddhi.vital_up.WIDGET_BACKGROUND"
    private const val NATIVE_PREFS = "vitalup_widget_native"
    private const val KEY_LAST_AUTO = "last_auto_refresh"

    /** Saved data older than this is refreshed by Dart when a widget updates. */
    private const val STALE_MS = 30 * 60 * 1000L

    /** Don't ask Dart again within this window (avoids loops if it fails). */
    private const val AUTO_THROTTLE_MS = 15 * 60 * 1000L

    fun signedIn(data: SharedPreferences) = data.getBoolean("signed_in", false)

    /** A refresh is running (set here or by the app); expires so it can't stick. */
    private const val REFRESH_TIMEOUT_MS = 20_000L

    fun isRefreshing(data: SharedPreferences): Boolean {
        val since = data.getString("refreshing_since_ms", null)?.toLongOrNull() ?: return false
        return System.currentTimeMillis() - since < REFRESH_TIMEOUT_MS
    }

    /** Dart clears this when it saves the refreshed data (publishWidgets). */
    fun markRefreshing(context: Context) {
        HomeWidgetPlugin.getData(context).edit()
            .putString("refreshing_since_ms", System.currentTimeMillis().toString())
            .apply()
    }

    /** Spinner in place of the refresh icon, and "Updating…" for the time. */
    fun showRefreshing(views: RemoteViews, refreshing: Boolean) {
        views.setViewVisibility(R.id.wg_refresh, if (refreshing) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.wg_refresh_progress, if (refreshing) View.VISIBLE else View.GONE)
        if (refreshing) views.setTextViewText(R.id.wg_updated, "Updating…")
    }

    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** Saved values belong to today (daily totals from yesterday are wrong). */
    fun isCurrent(data: SharedPreferences) = data.getString("snapshot_day", null) == today()

    private fun updatedAt(data: SharedPreferences): Long =
        data.getString("updated_at_ms", null)?.toLongOrNull() ?: 0L

    /**
     * "Updated 9:41 AM" (just "9:41 AM" when [short], for narrow widgets),
     * or a prompt when the data is from an earlier day.
     */
    fun updatedLabel(context: Context, data: SharedPreferences, short: Boolean = false): String {
        if (!isCurrent(data)) return if (short) "Tap ↻" else "Tap ↻ to update"
        val at = updatedAt(data)
        if (at == 0L) return ""
        val time = android.text.format.DateFormat.getTimeFormat(context).format(Date(at))
        return if (short) time else "Updated $time"
    }

    fun maybeAutoRefresh(context: Context, data: SharedPreferences) {
        if (!signedIn(data)) return
        val now = System.currentTimeMillis()
        val stale = !isCurrent(data) || now - updatedAt(data) > STALE_MS
        if (!stale) return
        val prefs = context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
        if (now - prefs.getLong(KEY_LAST_AUTO, 0L) < AUTO_THROTTLE_MS) return
        prefs.edit().putLong(KEY_LAST_AUTO, now).apply()
        runInDart(context, Uri.parse("vitalup://widget/refresh"))
    }

    /** Runs homeWidgetCallback in a background Dart isolate. */
    fun runInDart(context: Context, uri: Uri) {
        context.sendBroadcast(
            Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                action = "es.antonborri.home_widget.action.BACKGROUND"
                data = uri
            },
        )
    }

    /** Opens the app on [route] (GoRouter handles vitalup://widget/open). */
    fun open(context: Context, route: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("vitalup://widget/open?route=$route"),
        )

    /** A button that runs [path] in Dart without opening the app. */
    fun background(context: Context, provider: Class<*>, path: String): PendingIntent {
        val uri = Uri.parse("vitalup://widget/$path")
        val intent = Intent(context, provider).apply {
            action = ACTION_BACKGROUND
            data = uri
        }
        return PendingIntent.getBroadcast(
            context,
            uri.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun signedOut(context: Context): RemoteViews =
        RemoteViews(context.packageName, R.layout.wg_signed_out).apply {
            setOnClickPendingIntent(R.id.wg_root, open(context, "login"))
            setOnClickPendingIntent(R.id.wg_so_button, open(context, "login"))
        }

    fun bindHeader(
        views: RemoteViews,
        context: Context,
        data: SharedPreferences,
        title: String,
        provider: Class<*>,
        visible: Boolean = true,
        short: Boolean = false,
    ) {
        views.setViewVisibility(R.id.wg_header, if (visible) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.wg_title, title)
        views.setTextViewText(R.id.wg_updated, updatedLabel(context, data, short))
        showRefreshing(views, isRefreshing(data))
        views.setOnClickPendingIntent(R.id.wg_refresh, background(context, provider, "refresh"))
    }

    fun color(data: SharedPreferences, metric: String): Int {
        val hex = data.getString("m_${metric}_color", null)
        return try {
            if (hex != null) Color.parseColor(hex) else Color.parseColor("#FF19C3E0")
        } catch (_: IllegalArgumentException) {
            Color.parseColor("#FF19C3E0")
        }
    }

    fun icon(data: SharedPreferences, metric: String): Int = when (metric) {
        "activity" -> R.drawable.wg_ic_activity
        "calories" -> R.drawable.wg_ic_calories
        "water" -> R.drawable.wg_ic_water
        "sleep" -> R.drawable.wg_ic_sleep
        "weight" -> R.drawable.wg_ic_weight
        "mood" -> moodIcon(if (isCurrent(data)) data.getInt("mood_level", 0) else 0)
        else -> R.drawable.wg_ic_activity
    }

    fun moodIcon(level: Int): Int = when (level) {
        1 -> R.drawable.wg_ic_mood_1
        2 -> R.drawable.wg_ic_mood_2
        3 -> R.drawable.wg_ic_mood_3
        4 -> R.drawable.wg_ic_mood_4
        5 -> R.drawable.wg_ic_mood_5
        else -> R.drawable.wg_ic_mood
    }

    /** The metric ids saved by the app for a widget, e.g. "today_metrics". */
    fun metrics(data: SharedPreferences, key: String, fallback: String): List<String> =
        (data.getString(key, null) ?: fallback)
            .split(',')
            .map { it.trim() }
            .filter { it.isNotEmpty() }

    private val slotIds = listOf(
        intArrayOf(R.id.wg_slot1, R.id.wg_slot1_badge_bg, R.id.wg_slot1_icon, R.id.wg_slot1_label, R.id.wg_slot1_value, R.id.wg_slot1_detail, R.id.wg_slot1_bar),
        intArrayOf(R.id.wg_slot2, R.id.wg_slot2_badge_bg, R.id.wg_slot2_icon, R.id.wg_slot2_label, R.id.wg_slot2_value, R.id.wg_slot2_detail, R.id.wg_slot2_bar),
        intArrayOf(R.id.wg_slot3, R.id.wg_slot3_badge_bg, R.id.wg_slot3_icon, R.id.wg_slot3_label, R.id.wg_slot3_value, R.id.wg_slot3_detail, R.id.wg_slot3_bar),
        intArrayOf(R.id.wg_slot4, R.id.wg_slot4_badge_bg, R.id.wg_slot4_icon, R.id.wg_slot4_label, R.id.wg_slot4_value, R.id.wg_slot4_detail, R.id.wg_slot4_bar),
    )

    /** Fills slots 1-4 with [metrics]; unused slots are hidden. */
    fun bindSlots(views: RemoteViews, context: Context, data: SharedPreferences, metrics: List<String>, count: Int) {
        val current = isCurrent(data)
        for (i in 0 until 4) {
            val ids = slotIds[i]
            val metric = metrics.getOrNull(i)
            if (metric == null || i >= count) {
                views.setViewVisibility(ids[0], View.GONE)
                continue
            }
            val accent = color(data, metric)
            val progress = if (current) data.getInt("m_${metric}_progress", -1) else 0
            views.setViewVisibility(ids[0], View.VISIBLE)
            views.setInt(ids[1], "setColorFilter", accent)
            views.setImageViewResource(ids[2], icon(data, metric))
            views.setInt(ids[2], "setColorFilter", accent)
            views.setTextViewText(ids[3], data.getString("m_${metric}_label", "") ?: "")
            views.setTextViewText(ids[4], if (current) data.getString("m_${metric}_value", "—") ?: "—" else "—")
            views.setTextViewText(ids[5], data.getString("m_${metric}_detail", "") ?: "")
            if (progress < 0) {
                views.setViewVisibility(ids[6], View.INVISIBLE)
            } else {
                views.setViewVisibility(ids[6], View.VISIBLE)
                views.setInt(ids[6], "setImageLevel", progress.coerceIn(0, 100) * 100)
                views.setInt(ids[6], "setColorFilter", accent)
            }
            val route = data.getString("m_${metric}_route", null) ?: "dashboard"
            views.setOnClickPendingIntent(ids[0], open(context, route))
        }
    }
}
