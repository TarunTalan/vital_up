package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class StatsProgressWidgetProvider : HomeWidgetProvider() {
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

                // Root & Cards Tap -> Leaderboard / Points History
                val leaderIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=leaderboard"),
                )
                setOnClickPendingIntent(R.id.widget_stats_root, leaderIntent)
                setOnClickPendingIntent(R.id.widget_stats_streak_card, leaderIntent)
                setOnClickPendingIntent(R.id.widget_stats_points_card, leaderIntent)

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_stats_refresh_btn,
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
