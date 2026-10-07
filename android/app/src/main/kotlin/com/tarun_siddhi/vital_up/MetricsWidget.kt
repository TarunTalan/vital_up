package com.tarun_siddhi.vital_up

import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

/**
 * Metric tiles that adapt to the widget size: a list when narrow, a row of
 * columns when wide and short, a 2 x 2 grid when tall, plus quick actions
 * from 4 x 4.
 * Shared by Today and My metrics; they differ only in which metrics show.
 */
abstract class MetricsWidgetProvider : VitalWidgetProvider() {
    abstract val metricsKey: String
    abstract val defaultMetrics: String
    abstract fun title(data: SharedPreferences): String

    override val breakpoints = listOf(
        110 to 110, 110 to 170, 110 to 230,
        220 to 110, 290 to 110,
        220 to 170, 220 to 320,
    )

    override fun build(context: Context, data: SharedPreferences, widthDp: Int, heightDp: Int): RemoteViews {
        if (!Wg.signedIn(data)) return Wg.signedOut(context)
        val metrics = Wg.metrics(data, metricsKey, defaultMetrics)

        val views: RemoteViews
        val count: Int
        when {
            widthDp < 220 -> {
                views = RemoteViews(context.packageName, R.layout.wg_metrics_list)
                // Header and padding take about 48dp; each row needs about 44dp.
                count = ((heightDp - 48) / 44).coerceIn(1, 4)
            }
            heightDp < 170 -> {
                views = RemoteViews(context.packageName, R.layout.wg_metrics_row)
                count = if (widthDp < 290) 3 else 4
            }
            else -> {
                views = RemoteViews(context.packageName, R.layout.wg_metrics_grid)
                count = 4
                views.setViewVisibility(R.id.wg_grid_row2, if (metrics.size > 2) View.VISIBLE else View.GONE)
                // Buttons need a 4 x 4 or taller widget so the tiles keep their room.
                views.setViewVisibility(R.id.wg_actions, if (heightDp >= 320) View.VISIBLE else View.GONE)
                views.setOnClickPendingIntent(R.id.wg_action1, Wg.open(context, "food-scan"))
                views.setOnClickPendingIntent(R.id.wg_action2, Wg.background(context, javaClass, "add-water?ml=250"))
                views.setOnClickPendingIntent(R.id.wg_action3, Wg.open(context, "vita-chat"))
            }
        }
        Wg.bindHeader(views, context, data, title(data), javaClass, short = widthDp < 220)
        Wg.bindSlots(views, context, data, metrics, count)
        views.setOnClickPendingIntent(R.id.wg_root, Wg.open(context, "dashboard"))
        return views
    }
}

/** Today: the same four figures as the Home screen's Today card. */
open class VitalUpWidgetProvider : MetricsWidgetProvider() {
    override val metricsKey = "today_metrics"
    override val defaultMetrics = "activity,calories,water,sleep"
    override fun title(data: SharedPreferences) = "Today"
}

/** My metrics: the metrics and title chosen in the app's widget builder. */
open class CustomWidgetProvider : MetricsWidgetProvider() {
    override val metricsKey = "custom_metrics"
    override val defaultMetrics = "water,activity"
    override fun title(data: SharedPreferences) =
        data.getString("custom_title", null)?.takeIf { it.isNotBlank() } ?: "My metrics"
}
