package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget: today's water vs goal, streak and points, and a
 * "+250 ml" button. The values are written by HomeWidgetService
 * (lib/features/home_widget/home_widget_service.dart).
 */
class VitalUpWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val waterMl = widgetData.getInt("water_ml", 0)
        val goalMl = widgetData.getInt("water_goal_ml", 2500).coerceAtLeast(1)
        val streak = widgetData.getInt("streak", 0)
        val points = widgetData.getInt("points_today", 0)
        val signedIn = widgetData.getBoolean("signed_in", false)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.vitalup_widget).apply {
                setTextViewText(
                    R.id.widget_water,
                    if (signedIn) "%,d / %,d ml".format(waterMl, goalMl) else "Open VitalUp to start",
                )
                setProgressBar(
                    R.id.widget_water_progress,
                    100,
                    (waterMl * 100 / goalMl).coerceIn(0, 100),
                    false,
                )
                setTextViewText(R.id.widget_streak, if (streak > 0) "🔥 $streak" else "")
                setTextViewText(R.id.widget_points, if (signedIn) "+$points pts today" else "")

                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=water-trends"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_add_water,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("vitalup://widget/add-water"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
