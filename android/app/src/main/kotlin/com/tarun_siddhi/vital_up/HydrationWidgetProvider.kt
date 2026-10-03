package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HydrationWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val waterMl = widgetData.getInt("water_ml", 1750)
        val goalMl = widgetData.getInt("water_goal_ml", 2500).coerceAtLeast(1)
        val remaining = (goalMl - waterMl).coerceAtLeast(0)
        val percent = (waterMl * 100 / goalMl).coerceIn(0, 100)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.hydration_widget).apply {
                setTextViewText(R.id.widget_hydration_val, "%,d".format(waterMl))
                setTextViewText(R.id.widget_hydration_goal, "/ %,d ml".format(goalMl))
                setTextViewText(R.id.widget_hydration_remaining, "%,d ml left".format(remaining))
                setTextViewText(R.id.widget_hydration_percent, "$percent%")
                setProgressBar(R.id.widget_hydration_progress_bar, 100, percent, false)

                // Root Tap -> Water Trends
                setOnClickPendingIntent(
                    R.id.widget_hydration_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=water-trends"),
                    ),
                )

                // Quick +250 ml Action
                setOnClickPendingIntent(
                    R.id.widget_hydration_add_250,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("vitalup://widget/add-water"),
                    ),
                )

                // Quick +500 ml Action
                setOnClickPendingIntent(
                    R.id.widget_hydration_add_500,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("vitalup://widget/add-water-500"),
                    ),
                )

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_hydration_refresh_btn,
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
