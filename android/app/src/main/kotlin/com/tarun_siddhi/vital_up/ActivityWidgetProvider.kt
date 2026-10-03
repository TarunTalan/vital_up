package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ActivityWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val steps = widgetData.getInt("steps", 7420)
        val stepsGoal = widgetData.getInt("steps_goal", 10000).coerceAtLeast(1)
        val activeMin = widgetData.getInt("active_minutes", 42)
        val burned = widgetData.getInt("calories_burned", 380)
        val distanceKm = widgetData.getString("activity_distance", "5.2 km") ?: "5.2 km"
        val percent = (steps * 100 / stepsGoal).coerceIn(0, 100)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.activity_widget).apply {
                setTextViewText(R.id.widget_activity_steps, "%,d".format(steps))
                setTextViewText(R.id.widget_activity_goal, "/ %,d steps".format(stepsGoal))
                setTextViewText(R.id.widget_activity_percent, "$percent%")
                setProgressBar(R.id.widget_activity_progress_bar, 100, percent, false)

                setTextViewText(R.id.widget_activity_time, "$activeMin min")
                setTextViewText(R.id.widget_activity_burned, "$burned kcal")
                setTextViewText(R.id.widget_activity_distance, distanceKm)

                // Root & Track Button -> Activity Tracking Deep Link
                val activityIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=activity-tracking"),
                )
                setOnClickPendingIntent(R.id.widget_activity_root, activityIntent)
                setOnClickPendingIntent(R.id.widget_activity_track_btn, activityIntent)

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_activity_refresh_btn,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("vitalup://widget/refresh"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
