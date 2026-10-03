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

/**
 * Multi-Feature Vitals Home screen widget (Today's Activity & Nutrition)
 * matching the comprehensive preview card. Dynamically collapses Nutrition
 * breakdown on 4x2 / 3x2 (height 2) compact height.
 */
class VitalUpWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val data = intent.dataString
        if (intent.action == ACTION_WIDGET_ACTION || (data != null && (data.contains("widget/refresh") || data.contains("widget/add-water")))) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, VitalUpWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.vitalup_widget).apply {
                    setViewVisibility(R.id.widget_refresh_btn, View.GONE)
                    setViewVisibility(R.id.widget_refresh_progress, View.VISIBLE)
                }
                appWidgetManager.partiallyUpdateAppWidget(id, views)
            }

            // Fallback safety timeout: ensure loading state resets if background process drops or delays
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(ComponentName(context, VitalUpWidgetProvider::class.java))
                    for (wid in ids) {
                        val fallbackViews = RemoteViews(context.packageName, R.layout.vitalup_widget).apply {
                            setViewVisibility(R.id.widget_refresh_btn, View.VISIBLE)
                            setViewVisibility(R.id.widget_refresh_progress, View.GONE)
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
        val steps = widgetData.getInt("steps", 7420)
        val stepsGoal = widgetData.getInt("steps_goal", 10000).coerceAtLeast(1)
        val calories = widgetData.getInt("calories_consumed", 1640)
        val caloriesGoal = widgetData.getInt("calories_goal", 2000).coerceAtLeast(1)
        
        val protein = widgetData.getInt("protein_g", widgetData.getInt("protein_grams", 110))
        val proteinGoal = 130
        val carbs = widgetData.getInt("carbs_g", widgetData.getInt("carbs_grams", 185))
        val carbsGoal = 200
        val fat = widgetData.getInt("fat_g", widgetData.getInt("fat_grams", 52))
        val fatGoal = 60

        val signedIn = widgetData.getBoolean("signed_in", true)

        for (id in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(id)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)

            // Height 2 tiles (4x2, 3x2, 2x2) have minHeight <= 140dp and maxHeight <= 180dp.
            // Height 3+ tiles (4x3) have minHeight >= 180dp and maxHeight >= 210dp.
            // Nutrition card is ONLY shown on 3+ rows (4x3 full dashboard) and hidden on 3x2, 4x2, 2x2.
            val isThreeRowsOrMore = (minHeight >= 180) || (maxHeight >= 210)
            val isThreeColsOrMore = (minWidth >= 200) || (maxWidth >= 240)
            val showNutrition = isThreeRowsOrMore && isThreeColsOrMore

            val views = RemoteViews(context.packageName, R.layout.vitalup_widget).apply {
                setViewVisibility(R.id.widget_refresh_btn, View.VISIBLE)
                setViewVisibility(R.id.widget_refresh_progress, View.GONE)

                if (signedIn) {
                    setViewVisibility(R.id.widget_signed_in_container, View.VISIBLE)
                    setViewVisibility(R.id.widget_signed_out_container, View.GONE)

                    // Steps metrics
                    setTextViewText(R.id.widget_steps_text, "%,d".format(steps))
                    setTextViewText(R.id.widget_steps_goal, "/ %,d".format(stepsGoal))
                    setProgressBar(
                        R.id.widget_steps_progress,
                        100,
                        (steps * 100 / stepsGoal).coerceIn(0, 100),
                        false,
                    )

                    // Calories metrics
                    setTextViewText(R.id.widget_calories_text, "%,d".format(calories))
                    setTextViewText(R.id.widget_calories_goal, "/ %,d".format(caloriesGoal))
                    setProgressBar(
                        R.id.widget_calories_progress,
                        100,
                        (calories * 100 / caloriesGoal).coerceIn(0, 100),
                        false,
                    )

                    // Macros (Protein, Carbs, Fat) - only when height is not compact
                    if (showNutrition) {
                        setViewVisibility(R.id.widget_nutrition_card, View.VISIBLE)
                        setTextViewText(R.id.widget_protein_text, "${protein}g")
                        setProgressBar(
                            R.id.widget_protein_progress,
                            100,
                            (protein * 100 / proteinGoal).coerceIn(0, 100),
                            false,
                        )

                        setTextViewText(R.id.widget_carbs_text, "${carbs}g")
                        setProgressBar(
                            R.id.widget_carbs_progress,
                            100,
                            (carbs * 100 / carbsGoal).coerceIn(0, 100),
                            false,
                        )

                        setTextViewText(R.id.widget_fat_text, "${fat}g")
                        setProgressBar(
                            R.id.widget_fat_progress,
                            100,
                            (fat * 100 / fatGoal).coerceIn(0, 100),
                            false,
                        )
                    } else {
                        setViewVisibility(R.id.widget_nutrition_card, View.GONE)
                    }
                } else {
                    setViewVisibility(R.id.widget_signed_in_container, View.GONE)
                    setViewVisibility(R.id.widget_signed_out_container, View.VISIBLE)
                }

                // Root Tap: Open Dashboard (Multi-Feature default)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=dashboard"),
                    ),
                )

                // Steps Card Tap: Open Activity Tracking
                setOnClickPendingIntent(
                    R.id.widget_steps_card,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=activity-tracking"),
                    ),
                )

                // Calories Card Tap: Open Diet & Nutrition Progress
                setOnClickPendingIntent(
                    R.id.widget_calories_card,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=diet-progress"),
                    ),
                )

                // Nutrition Card Tap: Open Diet & Nutrition Progress
                setOnClickPendingIntent(
                    R.id.widget_nutrition_card,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=diet-progress"),
                    ),
                )

                // Quick Login
                setOnClickPendingIntent(
                    R.id.widget_quick_login_btn,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=login"),
                    ),
                )

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_refresh_btn,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/refresh"), 2001),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun createActionPendingIntent(context: Context, uri: Uri, requestCode: Int): PendingIntent {
        val intent = Intent(context, VitalUpWidgetProvider::class.java).apply {
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
        const val ACTION_WIDGET_ACTION = "com.tarun_siddhi.vital_up.WIDGET_ACTION_VITALUP"
    }
}
