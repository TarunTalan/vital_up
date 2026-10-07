package com.tarun_siddhi.vital_up

import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

/** Water today against the goal, with one-tap amounts logged in the background. */
open class HydrationWidgetProvider : VitalWidgetProvider() {
    override val breakpoints = listOf(110 to 110, 110 to 150, 220 to 110, 220 to 150)

    override fun layoutForPartialUpdate() = R.layout.wg_water_small

    override fun build(context: Context, data: SharedPreferences, widthDp: Int, heightDp: Int): RemoteViews {
        if (!Wg.signedIn(data)) return Wg.signedOut(context)
        val wide = widthDp >= 220
        val views = RemoteViews(
            context.packageName,
            if (wide) R.layout.wg_water_wide else R.layout.wg_water_small,
        )
        val current = Wg.isCurrent(data)
        val accent = Wg.color(data, "water")
        val progress = if (current) data.getInt("m_water_progress", 0) else 0

        Wg.bindHeader(views, context, data, "Water", javaClass, visible = heightDp >= 150, short = !wide)
        views.setInt(R.id.wg_water_badge_bg, "setColorFilter", accent)
        views.setInt(R.id.wg_water_icon, "setColorFilter", accent)
        views.setTextViewText(R.id.wg_water_value, if (current) data.getString("m_water_value", "—") else "—")
        views.setTextViewText(R.id.wg_water_detail, data.getString("m_water_detail", "") ?: "")
        views.setViewVisibility(R.id.wg_water_bar, if (progress < 0) View.INVISIBLE else View.VISIBLE)
        views.setInt(R.id.wg_water_bar, "setImageLevel", progress.coerceIn(0, 100) * 100)
        views.setInt(R.id.wg_water_bar, "setColorFilter", accent)

        views.setOnClickPendingIntent(R.id.wg_root, Wg.open(context, "water-trends"))
        views.setOnClickPendingIntent(R.id.wg_add2, Wg.background(context, javaClass, "add-water?ml=250"))
        if (wide) {
            views.setOnClickPendingIntent(R.id.wg_add1, Wg.background(context, javaClass, "add-water?ml=150"))
            views.setOnClickPendingIntent(R.id.wg_add3, Wg.background(context, javaClass, "add-water?ml=500"))
        }
        return views
    }
}
