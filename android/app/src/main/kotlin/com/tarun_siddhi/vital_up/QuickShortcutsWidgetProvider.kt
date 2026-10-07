package com.tarun_siddhi.vital_up

import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

/** Scan a meal, log water, start a workout, ask Vita; fewer when narrow. */
open class QuickShortcutsWidgetProvider : VitalWidgetProvider() {
    override val breakpoints = listOf(110 to 50, 180 to 50, 250 to 50)

    override fun build(context: Context, data: SharedPreferences, widthDp: Int, heightDp: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.wg_shortcuts)
        val count = when {
            widthDp < 180 -> 2
            widthDp < 250 -> 3
            else -> 4
        }
        val shortcuts = listOf(
            R.id.wg_sc1 to "food-scan",
            R.id.wg_sc2 to "water-log",
            R.id.wg_sc3 to "activity-tracking",
            R.id.wg_sc4 to "vita-chat",
        )
        val signedIn = Wg.signedIn(data)
        shortcuts.forEachIndexed { i, (id, route) ->
            views.setViewVisibility(id, if (i < count) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(id, Wg.open(context, if (signedIn) route else "login"))
        }
        return views
    }
}
