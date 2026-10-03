package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Multi-feature Home screen widget: today's water, steps, calories, streak,
 * points, fast actions (Scan, Activity, Vita AI), quick login, and top-right refresh.
 */
class VitalUpWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val waterMl = widgetData.getInt("water_ml", 0)
        val goalMl = widgetData.getInt("water_goal_ml", 2500).coerceAtLeast(1)
        val streak = widgetData.getInt("streak", 0)
        val points = widgetData.getInt("points_today", 0)
        val steps = widgetData.getInt("steps", 0)
        val stepsGoal = widgetData.getInt("steps_goal", 10000).coerceAtLeast(1)
        val calories = widgetData.getInt("calories_consumed", 0)
        val caloriesGoal = widgetData.getInt("calories_goal", 2000).coerceAtLeast(1)
        val signedIn = widgetData.getBoolean("signed_in", false)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.vitalup_widget).apply {
                if (signedIn) {
                    setViewVisibility(R.id.widget_signed_in_container, View.VISIBLE)
                    setViewVisibility(R.id.widget_signed_out_container, View.GONE)

                    // Water metrics
                    setTextViewText(R.id.widget_water, "%,d / %,d ml".format(waterMl, goalMl))
                    setProgressBar(
                        R.id.widget_water_progress,
                        100,
                        (waterMl * 100 / goalMl).coerceIn(0, 100),
                        false,
                    )

                    // Streak and points
                    setTextViewText(R.id.widget_streak, if (streak > 0) "🔥 $streak" else "")
                    setTextViewText(R.id.widget_points, if (points > 0) "+$points pts" else "")

                    // Steps metrics
                    setTextViewText(R.id.widget_steps_text, "%,d / %,d".format(steps, stepsGoal))
                    setProgressBar(
                        R.id.widget_steps_progress,
                        100,
                        (steps * 100 / stepsGoal).coerceIn(0, 100),
                        false,
                    )

                    // Calories metrics
                    setTextViewText(R.id.widget_calories_text, "%,d / %,d kcal".format(calories, caloriesGoal))
                    setProgressBar(
                        R.id.widget_calories_progress,
                        100,
                        (calories * 100 / caloriesGoal).coerceIn(0, 100),
                        false,
                    )
                } else {
                    setViewVisibility(R.id.widget_signed_in_container, View.GONE)
                    setViewVisibility(R.id.widget_signed_out_container, View.VISIBLE)
                    setTextViewText(R.id.widget_streak, "")
                    setTextViewText(R.id.widget_points, "")
                }

                // Root Tap (Multi-Feature): Launch Dashboard
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=dashboard"),
                    ),
                )

                // Streak & Points (Individual Feature): Leaderboard & XP Stats
                setOnClickPendingIntent(
                    R.id.widget_streak,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=leaderboard"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_points,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=leaderboard"),
                    ),
                )

                // Top-Right Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_refresh_btn,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("vitalup://widget/refresh"),
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

                // Quick Water Log (+250 ml)
                setOnClickPendingIntent(
                    R.id.widget_add_water,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("vitalup://widget/add-water"),
                    ),
                )

                // Water Card Tap -> Water Trends
                setOnClickPendingIntent(
                    R.id.widget_water_card,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=water-trends"),
                    ),
                )

                // Steps Card Tap -> Activity Tracking
                setOnClickPendingIntent(
                    R.id.widget_steps_card,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=activity-tracking"),
                    ),
                )

                // Calories Card Tap -> Food Scanner / Diet
                setOnClickPendingIntent(
                    R.id.widget_calories_card,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=food-scan"),
                    ),
                )

                // Action 1: Scan Food
                setOnClickPendingIntent(
                    R.id.widget_action_scan,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=food-scan"),
                    ),
                )

                // Action 2: Track Activity
                setOnClickPendingIntent(
                    R.id.widget_action_activity,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("vitalup://widget/open?route=activity-tracking"),
                    ),
                )

                // Action 3: Ask Vita AI
                setOnClickPendingIntent(
                    R.id.widget_action_vita,
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
