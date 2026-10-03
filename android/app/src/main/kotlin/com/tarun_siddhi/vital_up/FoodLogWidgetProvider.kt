package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FoodLogWidgetProvider : HomeWidgetProvider() {
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
            val views = RemoteViews(context.packageName, R.layout.food_log_widget).apply {
                setTextViewText(R.id.widget_food_calories, "%,d".format(calories))
                setTextViewText(R.id.widget_food_goal, "/ %,d kcal".format(caloriesGoal))
                setTextViewText(R.id.widget_food_remaining, "%,d kcal left".format(remaining))
                setProgressBar(
                    R.id.widget_food_progress_bar,
                    100,
                    (calories * 100 / caloriesGoal).coerceIn(0, 100),
                    false,
                )

                setTextViewText(R.id.widget_macro_protein, "${protein}g")
                setProgressBar(R.id.widget_macro_protein_progress, 100, (protein * 100 / 140).coerceIn(0, 100), false)

                setTextViewText(R.id.widget_macro_carbs, "${carbs}g")
                setProgressBar(R.id.widget_macro_carbs_progress, 100, (carbs * 100 / 250).coerceIn(0, 100), false)

                setTextViewText(R.id.widget_macro_fat, "${fat}g")
                setProgressBar(R.id.widget_macro_fat_progress, 100, (fat * 100 / 80).coerceIn(0, 100), false)

                // Root Tap -> Food Scanner / Meal History
                setOnClickPendingIntent(
                    R.id.widget_food_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=food-scan"),
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
