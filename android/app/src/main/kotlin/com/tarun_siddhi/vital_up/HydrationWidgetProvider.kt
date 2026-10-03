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

class HydrationWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val data = intent.dataString
        if (intent.action == ACTION_WIDGET_ACTION || (data != null && (data.contains("widget/refresh") || data.contains("widget/add-water")))) {
            // Show loading spinner immediately on user interaction
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, HydrationWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.hydration_widget).apply {
                    setViewVisibility(R.id.widget_hydration_refresh_btn, View.GONE)
                    setViewVisibility(R.id.widget_hydration_refresh_progress, View.VISIBLE)
                }
                appWidgetManager.partiallyUpdateAppWidget(id, views)
            }

            // Fallback safety timeout: ensure loading state resets if background process drops or delays
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(ComponentName(context, HydrationWidgetProvider::class.java))
                    for (wid in ids) {
                        val fallbackViews = RemoteViews(context.packageName, R.layout.hydration_widget).apply {
                            setViewVisibility(R.id.widget_hydration_refresh_btn, View.VISIBLE)
                            setViewVisibility(R.id.widget_hydration_refresh_progress, View.GONE)
                        }
                        mgr.partiallyUpdateAppWidget(wid, fallbackViews)
                    }
                } catch (_: Exception) {}
            }, 6000L)

            // Forward to HomeWidgetBackgroundReceiver to execute Dart background callback
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
        val waterMl = widgetData.getInt("water_ml", 1750)
        val goalMl = widgetData.getInt("water_goal_ml", 2500).coerceAtLeast(1)
        val percent = (waterMl * 100 / goalMl).coerceIn(0, 100)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.hydration_widget).apply {
                setTextViewText(R.id.widget_hydration_val, "%,d ml".format(waterMl))
                setTextViewText(R.id.widget_hydration_goal_percent, "Goal: %,d ml (%d%%)".format(goalMl, percent))
                
                // Set Circular Progress Ring
                setProgressBar(R.id.widget_hydration_circular_progress, 100, percent, false)

                // Reset Refresh Spinner
                setViewVisibility(R.id.widget_hydration_refresh_btn, View.VISIBLE)
                setViewVisibility(R.id.widget_hydration_refresh_progress, View.GONE)

                // Root Tap -> Water Trends
                setOnClickPendingIntent(
                    R.id.widget_hydration_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=water-trends"),
                    ),
                )

                // Quick +100 ml Action
                setOnClickPendingIntent(
                    R.id.widget_hydration_add_100,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/add-water-100"), 1001),
                )

                // Quick +250 ml Action
                setOnClickPendingIntent(
                    R.id.widget_hydration_add_250,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/add-water"), 1002),
                )

                // Quick +500 ml Action
                setOnClickPendingIntent(
                    R.id.widget_hydration_add_500,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/add-water-500"), 1003),
                )

                // Quick +1000 ml Action
                setOnClickPendingIntent(
                    R.id.widget_hydration_add_1000,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/add-water-1000"), 1004),
                )

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_hydration_refresh_btn,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/refresh"), 1005),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun createActionPendingIntent(context: Context, uri: Uri, requestCode: Int): PendingIntent {
        val intent = Intent(context, HydrationWidgetProvider::class.java).apply {
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
        const val ACTION_WIDGET_ACTION = "com.tarun_siddhi.vital_up.WIDGET_ACTION_HYDRATION"
    }
}
