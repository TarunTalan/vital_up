package com.tarun_siddhi.vital_up

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class MoodWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val data = intent.dataString
        if (intent.action == ACTION_WIDGET_ACTION || (data != null && (data.contains("widget/refresh") || data.contains("widget/select-mood") || data.contains("widget/toggle-tag") || data.contains("widget/submit-mood") || data.contains("widget/log-mood") || data.contains("widget/reset-mood")))) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, MoodWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            val prefs = HomeWidgetPlugin.getData(context)
            val uri = intent.data

            if (uri != null && (uri.path?.contains("select-mood") == true || uri.path?.contains("log-mood") == true)) {
                val level = uri.getQueryParameter("level")?.toIntOrNull() ?: 2
                prefs.edit().putInt("mood_selected_level", level).apply()
                onUpdate(context, appWidgetManager, allWidgetIds, prefs)
                return
            } else if (uri != null && uri.path?.contains("toggle-tag") == true) {
                val tag = uri.getQueryParameter("tag") ?: ""
                if (tag.isNotEmpty()) {
                    val currentTags = prefs.getString("mood_selected_tags", "") ?: ""
                    val tagList = if (currentTags.isEmpty()) mutableListOf() else currentTags.split(",").toMutableList()
                    if (tagList.contains(tag)) {
                        tagList.remove(tag)
                    } else {
                        tagList.add(tag)
                    }
                    prefs.edit().putString("mood_selected_tags", tagList.joinToString(",")).apply()
                    onUpdate(context, appWidgetManager, allWidgetIds, prefs)
                }
                return
            } else if (uri != null && (uri.path?.contains("submit-mood") == true || uri.path?.contains("checkin-mood") == true)) {
                val level = prefs.getInt("mood_selected_level", 2).coerceIn(1, 5)
                val currentTags = prefs.getString("mood_selected_tags", "") ?: ""
                val moodState = when (level) {
                    1 -> "Very calm"
                    2 -> "Calm"
                    3 -> "Okay"
                    4 -> "Stressed"
                    5 -> "Very stressed"
                    else -> "Calm"
                }
                val defaultSubtitle = when (level) {
                    1, 2 -> "Nice — keep that calm going."
                    3 -> "Steady day. A short walk can lift it."
                    else -> "Tough one. Try a 2-minute breathing break."
                }
                val finalSubtitle = if (currentTags.isNotEmpty()) {
                    currentTags.split(",").joinToString(" · ")
                } else {
                    defaultSubtitle
                }

                prefs.edit()
                    .putBoolean("mood_logged_today", true)
                    .putInt("mood_level", level)
                    .putString("mood_state", moodState)
                    .putString("mood_subtitle", finalSubtitle)
                    .apply()

                onUpdate(context, appWidgetManager, allWidgetIds, prefs)
            } else if (uri != null && (uri.path?.contains("reset-mood") == true || uri.path?.contains("edit-mood") == true)) {
                prefs.edit()
                    .putBoolean("mood_logged_today", false)
                    .putString("mood_selected_tags", "")
                    .apply()

                onUpdate(context, appWidgetManager, allWidgetIds, prefs)
            } else if (data != null && data.contains("widget/refresh")) {
                for (id in allWidgetIds) {
                    val layoutRes = getLayoutForWidget(appWidgetManager, id)
                    val views = RemoteViews(context.packageName, layoutRes).apply {
                        setViewVisibility(R.id.widget_mood_refresh_btn, View.GONE)
                        setViewVisibility(R.id.widget_mood_refresh_progress, View.VISIBLE)
                    }
                    appWidgetManager.partiallyUpdateAppWidget(id, views)
                }

                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        val mgr = AppWidgetManager.getInstance(context)
                        val ids = mgr.getAppWidgetIds(ComponentName(context, MoodWidgetProvider::class.java))
                        for (wid in ids) {
                            val layoutRes = getLayoutForWidget(mgr, wid)
                            val fallbackViews = RemoteViews(context.packageName, layoutRes).apply {
                                setViewVisibility(R.id.widget_mood_refresh_btn, View.VISIBLE)
                                setViewVisibility(R.id.widget_mood_refresh_progress, View.GONE)
                            }
                            mgr.partiallyUpdateAppWidget(wid, fallbackViews)
                        }
                    } catch (_: Exception) {}
                }, 6000L)
            }

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
        val isLoggedToday = widgetData.getBoolean("mood_logged_today", false)
        val selectedLevel = widgetData.getInt("mood_selected_level", 2).coerceIn(1, 5)
        val loggedLevel = widgetData.getInt("mood_level", selectedLevel).coerceIn(1, 5)
        val selectedTags = widgetData.getString("mood_selected_tags", "") ?: ""
        val tagList = if (selectedTags.isEmpty()) emptyList() else selectedTags.split(",")

        val moodState = widgetData.getString("mood_state", when (loggedLevel) {
            1 -> "Very calm"
            2 -> "Calm"
            3 -> "Okay"
            4 -> "Stressed"
            5 -> "Very stressed"
            else -> "Calm"
        }) ?: "Calm"

        val moodSubtitle = widgetData.getString("mood_subtitle", when (loggedLevel) {
            1, 2 -> "Nice — keep that calm going."
            3 -> "Steady day. A short walk can lift it."
            else -> "Tough one. Try a 2-minute breathing break."
        }) ?: "Nice — keep that calm going."

        val moodIconRes = when (loggedLevel) {
            1 -> R.drawable.ic_widget_mood_1
            2 -> R.drawable.ic_widget_mood_2
            3 -> R.drawable.ic_widget_mood_3
            4 -> R.drawable.ic_widget_mood_4
            5 -> R.drawable.ic_widget_mood_5
            else -> R.drawable.ic_widget_mood_2
        }
        val streak = widgetData.getInt("streak", 3)

        val moodLogIds = intArrayOf(
            R.id.mood_log_1,
            R.id.mood_log_2,
            R.id.mood_log_3,
            R.id.mood_log_4,
            R.id.mood_log_5,
        )
        val selectedDrawables = intArrayOf(
            R.drawable.widget_mood_circle_selected_1,
            R.drawable.widget_mood_circle_selected_2,
            R.drawable.widget_mood_circle_selected_3,
            R.drawable.widget_mood_circle_selected_4,
            R.drawable.widget_mood_circle_selected_5,
        )

        val tagMap = mapOf(
            "Work" to R.id.mood_tag_work,
            "Sleep" to R.id.mood_tag_sleep,
            "Family" to R.id.mood_tag_family,
            "Health" to R.id.mood_tag_health,
            "Money" to R.id.mood_tag_money,
            "Social" to R.id.mood_tag_social,
            "Other" to R.id.mood_tag_other,
        )

        for (id in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(id)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            val effectiveHeight = if (minHeight > 0) minHeight else (if (maxHeight > 0) maxHeight else 240)

            // Default to height 4 (tall layout with proper spacing and taller chips/button)
            val layoutRes = if (effectiveHeight >= 180) R.layout.mood_widget_tall else R.layout.mood_widget

            val views = RemoteViews(context.packageName, layoutRes).apply {
                setViewVisibility(R.id.widget_mood_refresh_btn, View.VISIBLE)
                setViewVisibility(R.id.widget_mood_refresh_progress, View.GONE)

                // Streak Pill matching dashboard StressCheckInCard & Preview
                val streakText = if (streak > 0) {
                    if (isLoggedToday) "$streak-day streak" else "$streak-day streak · check in to keep it"
                } else {
                    "Check in today to start a streak"
                }
                setTextViewText(R.id.widget_mood_streak_pill_text, streakText)
                setViewVisibility(R.id.widget_mood_streak_pill, View.VISIBLE)

                // Streak Pill Tap -> Points & Streak History
                val streakIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=points-history"),
                )
                setOnClickPendingIntent(R.id.widget_mood_streak_pill, streakIntent)

                // Switch between Logged View and Picker View
                if (isLoggedToday) {
                    setViewVisibility(R.id.widget_mood_picker_container, View.GONE)
                    setViewVisibility(R.id.widget_mood_logged_container, View.VISIBLE)

                    setImageViewResource(R.id.widget_mood_logged_icon, moodIconRes)
                    setTextViewText(R.id.widget_mood_logged_title, "Feeling $moodState today")
                    setTextViewText(R.id.widget_mood_logged_subtitle, moodSubtitle)

                    // Edit button -> Resets logged value and returns to 5 face picker
                    setOnClickPendingIntent(
                        R.id.widget_mood_edit_btn,
                        createActionPendingIntent(context, Uri.parse("vitalup://widget/reset-mood"), 3009),
                    )
                } else {
                    setViewVisibility(R.id.widget_mood_logged_container, View.GONE)
                    setViewVisibility(R.id.widget_mood_picker_container, View.VISIBLE)

                    // 5 Mood Face Selection Intents & Visual Highlight Rings
                    for (i in 0 until 5) {
                        val level = i + 1
                        val viewId = moodLogIds[i]
                        val isSelected = (selectedLevel == level)
                        val bgDrawable = if (isSelected) selectedDrawables[i] else R.drawable.widget_mood_circle_unselected

                        setInt(viewId, "setBackgroundResource", bgDrawable)
                        setOnClickPendingIntent(
                            viewId,
                            createActionPendingIntent(context, Uri.parse("vitalup://widget/select-mood?level=$level"), 3010 + level),
                        )
                    }

                    // Tag Chips Toggle Intents & Visual Selection State
                    val selectedTextColor = context.getColor(R.color.widget_mood)
                    val unselectedTextColor = context.getColor(R.color.widget_text)
                    var tagReqCode = 3021
                    for ((tag, viewId) in tagMap) {
                        val isSelected = tagList.contains(tag)
                        setInt(viewId, "setBackgroundResource", if (isSelected) R.drawable.widget_chip_selected_bg else R.drawable.widget_chip_bg)
                        setTextColor(viewId, if (isSelected) selectedTextColor else unselectedTextColor)
                        setTextViewText(viewId, if (isSelected) "✓ $tag" else tag)
                        setOnClickPendingIntent(
                            viewId,
                            createActionPendingIntent(context, Uri.parse("vitalup://widget/toggle-tag?tag=$tag"), tagReqCode++),
                        )
                    }

                    // Check In Button
                    setTextColor(R.id.widget_mood_checkin_btn, context.getColor(R.color.widget_btn_text))
                    setOnClickPendingIntent(
                        R.id.widget_mood_checkin_btn,
                        createActionPendingIntent(context, Uri.parse("vitalup://widget/submit-mood"), 3030),
                    )
                }

                // Root Tap -> Opens Stress / Mood Trends in-app
                val moodTrendsIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=stress-trends"),
                )
                setOnClickPendingIntent(R.id.widget_mood_root, moodTrendsIntent)

                // Refresh Button
                setOnClickPendingIntent(
                    R.id.widget_mood_refresh_btn,
                    createActionPendingIntent(context, Uri.parse("vitalup://widget/refresh"), 3001),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun getLayoutForWidget(appWidgetManager: AppWidgetManager, id: Int): Int {
        val options = appWidgetManager.getAppWidgetOptions(id)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        val effectiveHeight = if (minHeight > 0) minHeight else (if (maxHeight > 0) maxHeight else 240)
        return if (effectiveHeight >= 180) R.layout.mood_widget_tall else R.layout.mood_widget
    }

    private fun createActionPendingIntent(context: Context, uri: Uri, requestCode: Int): PendingIntent {
        val intent = Intent(context, MoodWidgetProvider::class.java).apply {
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
        const val ACTION_WIDGET_ACTION = "com.tarun_siddhi.vital_up.WIDGET_ACTION_MOOD"
    }
}
