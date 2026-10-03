package com.tarun_siddhi.vital_up

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

import android.os.Handler
import android.os.Looper

class SleepWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val data = intent.dataString
        if (intent.action == ACTION_WIDGET_ACTION || (data != null && data.contains("widget/refresh"))) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SleepWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.sleep_widget).apply {
                    setViewVisibility(R.id.widget_sleep_refresh_btn, View.GONE)
                    setViewVisibility(R.id.widget_sleep_refresh_progress, View.VISIBLE)
                }
                appWidgetManager.partiallyUpdateAppWidget(id, views)
            }

            // Fallback safety timeout: ensure loading state resets if background process drops or delays
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(ComponentName(context, SleepWidgetProvider::class.java))
                    for (wid in ids) {
                        val fallbackViews = RemoteViews(context.packageName, R.layout.sleep_widget).apply {
                            setViewVisibility(R.id.widget_sleep_refresh_btn, View.VISIBLE)
                            setViewVisibility(R.id.widget_sleep_refresh_progress, View.GONE)
                        }
                        mgr.partiallyUpdateAppWidget(wid, fallbackViews)
                    }
                } catch (_: Exception) {}
            }, 6000L)

            val bgIntent = Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                action = "es.antonborri.home_widget.action.BACKGROUND"
                this.data = intent.data
            }
            context.sendBroadcast(bgIntent)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), widgetData)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

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
                // Ensure refresh button is visible and progress hidden after update
                setViewVisibility(R.id.widget_sleep_refresh_btn, View.VISIBLE)
                setViewVisibility(R.id.widget_sleep_refresh_progress, View.GONE)

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
                val refreshIntent = Intent(context, SleepWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_ACTION
                    data = Uri.parse("vitalup://widget/refresh")
                }
                val pendingRefresh = PendingIntent.getBroadcast(
                    context,
                    700,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                setOnClickPendingIntent(R.id.widget_sleep_refresh_btn, pendingRefresh)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    companion object {
        const val ACTION_WIDGET_ACTION = "com.tarun_siddhi.vital_up.WIDGET_ACTION_SLEEP"
    }
}
