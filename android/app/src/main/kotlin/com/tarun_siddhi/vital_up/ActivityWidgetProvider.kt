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
        val streak = widgetData.getInt("streak", 3)
        val percent = (steps * 100 / stepsGoal).coerceIn(0, 100)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.activity_widget).apply {
                setTextViewText(R.id.widget_activity_steps, "%,d".format(steps))
                setTextViewText(R.id.widget_activity_goal, "Goal: %,d steps".format(stepsGoal))
                setProgressBar(R.id.widget_activity_progress, 100, percent, false)
                
                setTextViewText(R.id.widget_activity_streak, "🔥 $streak days")

                // Root & Track Button -> Activity Tracking Deep Link
                val activityIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=activity-tracking"),
                )
                setOnClickPendingIntent(R.id.widget_activity_root, activityIntent)
                setOnClickPendingIntent(R.id.widget_activity_track_btn, activityIntent)

                // Streak Tap -> Points & Streak History
                val streakIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=points-history"),
                )
                setOnClickPendingIntent(R.id.widget_activity_streak, streakIntent)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
