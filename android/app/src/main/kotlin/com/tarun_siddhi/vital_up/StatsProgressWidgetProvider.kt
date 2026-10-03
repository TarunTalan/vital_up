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

class StatsProgressWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val data = intent.dataString
        if (intent.action == ACTION_WIDGET_ACTION || (data != null && data.contains("widget/refresh"))) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, StatsProgressWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.stats_progress_widget).apply {
                    setViewVisibility(R.id.widget_stats_refresh_btn, View.GONE)
                    setViewVisibility(R.id.widget_stats_refresh_progress, View.VISIBLE)
                }
                appWidgetManager.partiallyUpdateAppWidget(id, views)
            }

            // Fallback safety timeout: ensure loading state resets if background process drops or delays
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(ComponentName(context, StatsProgressWidgetProvider::class.java))
                    for (wid in ids) {
                        val fallbackViews = RemoteViews(context.packageName, R.layout.stats_progress_widget).apply {
                            setViewVisibility(R.id.widget_stats_refresh_btn, View.VISIBLE)
                            setViewVisibility(R.id.widget_stats_refresh_progress, View.GONE)
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
        val streak = widgetData.getInt("streak", 5)
        val points = widgetData.getInt("points_today", 120)
        val rankTag = widgetData.getString("stats_rank_tag", "Level 4 • Rank #4") ?: "Level 4 • Rank #4"
        val goalsDone = widgetData.getInt("goals_completed", 4)
        val goalsTotal = widgetData.getInt("goals_total", 5).coerceAtLeast(1)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.stats_progress_widget).apply {
                setViewVisibility(R.id.widget_stats_refresh_btn, View.VISIBLE)
                setViewVisibility(R.id.widget_stats_refresh_progress, View.GONE)
                setTextViewText(R.id.widget_stats_rank_tag, rankTag)
                setTextViewText(R.id.widget_stats_streak_val, "🔥 $streak Days")
                setTextViewText(R.id.widget_stats_points_val, "⚡ +$points pts")
                setTextViewText(
                    R.id.widget_stats_goals_text,
                    "$goalsDone of $goalsTotal (%d%%)".format(goalsDone * 100 / goalsTotal),
                )
                setProgressBar(
                    R.id.widget_stats_progress_bar,
                    100,
                    (goalsDone * 100 / goalsTotal).coerceIn(0, 100),
                    false,
                )

                // Root & Cards Tap -> Points & Streak History
                val pointsIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=points-history"),
                )
                setOnClickPendingIntent(R.id.widget_stats_root, pointsIntent)
                setOnClickPendingIntent(R.id.widget_stats_streak_card, pointsIntent)
                setOnClickPendingIntent(R.id.widget_stats_points_card, pointsIntent)

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_stats_refresh_btn,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/refresh"), 5001),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun createActionPendingIntent(context: Context, uri: Uri, requestCode: Int): PendingIntent {
        val intent = Intent(context, StatsProgressWidgetProvider::class.java).apply {
            action = ACTION_WIDGET_ACTION
            data = uri
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val ACTION_WIDGET_ACTION = "com.tarun_siddhi.vital_up.WIDGET_ACTION_STATS"
    }
}
