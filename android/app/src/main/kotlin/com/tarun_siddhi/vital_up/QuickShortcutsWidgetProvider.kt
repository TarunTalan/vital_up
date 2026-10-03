package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class QuickShortcutsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_shortcuts_widget).apply {
                // Water Shortcut -> Water Trends
                setOnClickPendingIntent(
                    R.id.widget_shortcut_water,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=water-trends"),
                    ),
                )

                // Activity Shortcut -> Activity Tracking
                setOnClickPendingIntent(
                    R.id.widget_shortcut_activity,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=activity-tracking"),
                    ),
                )

                // Food Shortcut -> Food Scanner
                setOnClickPendingIntent(
                    R.id.widget_shortcut_food,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=food-scan"),
                    ),
                )

                // Vita AI Shortcut -> Vita Chat
                setOnClickPendingIntent(
                    R.id.widget_shortcut_vita,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=vita-chat"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
