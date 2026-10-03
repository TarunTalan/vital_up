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

class FoodLogWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val data = intent.dataString
        if (intent.action == ACTION_WIDGET_ACTION || (data != null && data.contains("widget/refresh"))) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, FoodLogWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.food_log_widget).apply {
                    setViewVisibility(R.id.widget_food_refresh_btn, View.GONE)
                    setViewVisibility(R.id.widget_food_refresh_progress, View.VISIBLE)
                }
                appWidgetManager.partiallyUpdateAppWidget(id, views)
            }

            // Fallback safety timeout: ensure loading state resets if background process drops or delays
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(ComponentName(context, FoodLogWidgetProvider::class.java))
                    for (wid in ids) {
                        val fallbackViews = RemoteViews(context.packageName, R.layout.food_log_widget).apply {
                            setViewVisibility(R.id.widget_food_refresh_btn, View.VISIBLE)
                            setViewVisibility(R.id.widget_food_refresh_progress, View.GONE)
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
        val calories = widgetData.getInt("calories_consumed", 1640)
        val caloriesGoal = widgetData.getInt("calories_goal", 2000).coerceAtLeast(1)
        val protein = widgetData.getInt("protein_g", 110)
        val carbs = widgetData.getInt("carbs_g", 185)
        val fat = widgetData.getInt("fat_g", 52)
        val remaining = (caloriesGoal - calories).coerceAtLeast(0)

        for (id in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(id)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            val effectiveHeight = if (minHeight > 0) minHeight else (if (maxHeight > 0) maxHeight else 110)
            val effectiveWidth = if (minWidth > 0) minWidth else (if (maxWidth > 0) maxWidth else 250)

            // 2x2 or compact tile removes the macro breakdown cards
            val showMacros = effectiveHeight >= 115 && effectiveWidth >= 200

            val views = RemoteViews(context.packageName, R.layout.food_log_widget).apply {
                setViewVisibility(R.id.widget_food_refresh_btn, View.VISIBLE)
                setViewVisibility(R.id.widget_food_refresh_progress, View.GONE)
                setTextViewText(R.id.widget_food_calories, "%,d".format(calories))
                setTextViewText(R.id.widget_food_goal, "/ %,d kcal".format(caloriesGoal))
                setTextViewText(R.id.widget_food_remaining, "%,d kcal left".format(remaining))
                setProgressBar(
                    R.id.widget_food_progress_bar,
                    100,
                    (calories * 100 / caloriesGoal).coerceIn(0, 100),
                    false,
                )

                if (showMacros) {
                    setViewVisibility(R.id.widget_food_macros_container, View.VISIBLE)
                    setTextViewText(R.id.widget_macro_protein, "${protein}g")
                    setProgressBar(R.id.widget_macro_protein_progress, 100, (protein * 100 / 140).coerceIn(0, 100), false)

                    setTextViewText(R.id.widget_macro_carbs, "${carbs}g")
                    setProgressBar(R.id.widget_macro_carbs_progress, 100, (carbs * 100 / 250).coerceIn(0, 100), false)

                    setTextViewText(R.id.widget_macro_fat, "${fat}g")
                    setProgressBar(R.id.widget_macro_fat_progress, 100, (fat * 100 / 80).coerceIn(0, 100), false)
                } else {
                    setViewVisibility(R.id.widget_food_macros_container, View.GONE)
                }

                // Root Tap -> Diet & Nutrition Progress
                setOnClickPendingIntent(
                    R.id.widget_food_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=diet-progress"),
                    ),
                )

                // Scan Button
                setOnClickPendingIntent(
                    R.id.widget_food_scan_btn,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=food-scan"),
                    ),
                )

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_food_refresh_btn,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/refresh"), 4001),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun createActionPendingIntent(context: Context, uri: Uri, requestCode: Int): PendingIntent {
        val intent = Intent(context, FoodLogWidgetProvider::class.java).apply {
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
        const val ACTION_WIDGET_ACTION = "com.tarun_siddhi.vital_up.WIDGET_ACTION_FOOD"
    }
}
