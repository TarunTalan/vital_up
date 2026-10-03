package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SleepWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val sleepMinutes = widgetData.getInt("sleep_minutes", 465)
        val sleepGoalMinutes = widgetData.getInt("sleep_goal_minutes", 480).coerceAtLeast(1)
        val sleepScore = widgetData.getInt("sleep_score", 88)
        val hours = sleepMinutes / 60
        val mins = sleepMinutes % 60
        val goalHours = sleepGoalMinutes / 60
        val goalMins = sleepGoalMinutes % 60

        val bedtime = widgetData.getString("sleep_bedtime", "11:15 PM") ?: "11:15 PM"
        val waketime = widgetData.getString("sleep_waketime", "07:00 AM") ?: "07:00 AM"
        val deepSleep = widgetData.getString("sleep_deep", "1h 45m") ?: "1h 45m"

        val qualityTag = when {
            sleepScore >= 85 -> "Optimal"
            sleepScore >= 70 -> "Good"
            else -> "Fair"
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.sleep_widget).apply {
                setTextViewText(R.id.widget_sleep_duration, "%dh %02dm".format(hours, mins))
                setTextViewText(
                    R.id.widget_sleep_goal,
                    if (goalMins > 0) "/ %dh %02dm goal".format(goalHours, goalMins) else "/ %dh goal".format(goalHours),
                )
                setTextViewText(R.id.widget_sleep_score, "$sleepScore% Score")
                setTextViewText(R.id.widget_sleep_quality_tag, qualityTag)
                setProgressBar(
                    R.id.widget_sleep_progress_bar,
                    100,
                    (sleepMinutes * 100 / sleepGoalMinutes).coerceIn(0, 100),
                    false,
                )
                setTextViewText(R.id.widget_sleep_bedtime, bedtime)
                setTextViewText(R.id.widget_sleep_waketime, waketime)
                setTextViewText(R.id.widget_sleep_deep, deepSleep)

                // Root & Elements Tap -> Sleep Trends Deep Link
                val sleepIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=sleep-trends"),
                )
                setOnClickPendingIntent(R.id.widget_sleep_root, sleepIntent)

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_sleep_refresh_btn,
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
