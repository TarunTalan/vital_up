package com.tarun_siddhi.vital_up

import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

/**
 * One-tap stress check-in: five faces (very calm to very stressed) until
 * today is logged, then today's mood with a Change button. At one row high
 * it drops the header.
 */
open class MoodWidgetProvider : VitalWidgetProvider() {
    override val breakpoints = listOf(180 to 50, 180 to 110, 250 to 110)

    override fun layoutForPartialUpdate() = R.layout.wg_mood

    private val faces = intArrayOf(R.id.wg_face1, R.id.wg_face2, R.id.wg_face3, R.id.wg_face4, R.id.wg_face5)

    override fun build(context: Context, data: SharedPreferences, widthDp: Int, heightDp: Int): RemoteViews {
        if (!Wg.signedIn(data)) return Wg.signedOut(context)
        val compact = heightDp < 100
        val views = RemoteViews(
            context.packageName,
            if (compact) R.layout.wg_mood_compact else R.layout.wg_mood,
        )
        val level = if (Wg.isCurrent(data)) data.getInt("mood_level", 0) else 0
        val logged = level in 1..5

        if (!compact) {
            val title = if (logged) "Today's mood" else "How are you feeling?"
            Wg.bindHeader(views, context, data, title, javaClass, short = widthDp < 220)
        }
        views.setViewVisibility(R.id.wg_mood_pick, if (logged) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.wg_mood_done, if (logged) View.VISIBLE else View.GONE)

        if (logged) {
            val accent = Wg.color(data, "mood")
            views.setInt(R.id.wg_mood_badge_bg, "setColorFilter", accent)
            views.setImageViewResource(R.id.wg_mood_icon, Wg.moodIcon(level))
            views.setInt(R.id.wg_mood_icon, "setColorFilter", accent)
            views.setTextViewText(R.id.wg_mood_value, data.getString("m_mood_value", "") ?: "")
            views.setTextViewText(R.id.wg_mood_detail, data.getString("m_mood_detail", "") ?: "")
            views.setOnClickPendingIntent(R.id.wg_mood_change, Wg.background(context, javaClass, "mood-reset"))
        } else {
            faces.forEachIndexed { i, id ->
                views.setOnClickPendingIntent(id, Wg.background(context, javaClass, "mood?level=${i + 1}"))
            }
        }
        views.setOnClickPendingIntent(R.id.wg_root, Wg.open(context, "stress-trends"))
        return views
    }
}
