package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MoodWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val moodEmoji = widgetData.getString("mood_emoji", "😊") ?: "😊"
        val moodState = widgetData.getString("mood_state", "Calm & Focused") ?: "Calm & Focused"
        val stressLevel = widgetData.getInt("stress_level", 24)
        val mindfulMin = widgetData.getInt("mindful_minutes", 15)
        val hrv = widgetData.getString("hrv_text", "68 ms (Good)") ?: "68 ms (Good)"

        val stressText = when {
            stressLevel < 30 -> "Low Stress • $stressLevel%"
            stressLevel < 60 -> "Moderate Stress • $stressLevel%"
            else -> "High Stress • $stressLevel%"
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.mood_widget).apply {
                setTextViewText(R.id.widget_mood_emoji, moodEmoji)
                setTextViewText(R.id.widget_mood_state, moodState)
                setTextViewText(R.id.widget_stress_state, stressText)
                setProgressBar(R.id.widget_mood_progress_bar, 100, (100 - stressLevel).coerceIn(0, 100), false)
                setTextViewText(R.id.widget_mindful_time, "$mindfulMin min today")
                setTextViewText(R.id.widget_hrv_text, hrv)

                // Root & Check-in -> Stress Trends Deep Link
                val moodIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=stress-trends"),
                )
                setOnClickPendingIntent(R.id.widget_mood_root, moodIntent)
                setOnClickPendingIntent(R.id.widget_mood_checkin_btn, moodIntent)

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_mood_refresh_btn,
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
