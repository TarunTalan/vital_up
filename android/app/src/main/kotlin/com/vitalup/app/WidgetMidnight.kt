package com.vitalup.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.Calendar

/**
 * Redraws every widget just after local midnight, so yesterday's daily
 * totals and details don't stay up until the next 30 minute update (or
 * longer in Doze). The redraw masks the old day's figures and asks Dart
 * for today's (VitalWidgetProvider.onUpdate -> Wg.maybeAutoRefresh).
 *
 * An inexact alarm that may run while idle: no exact-alarm permission,
 * and a few minutes late is fine. Re-armed on every widget update, and on
 * clock or time zone changes, which move midnight.
 */
class WidgetMidnightReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        updateAllWidgets(context)
        WidgetMidnight.schedule(context)
    }

    private fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (info in manager.getInstalledProvidersForPackage(context.packageName, null)) {
            val ids = manager.getAppWidgetIds(info.provider)
            if (ids.isEmpty()) continue
            context.sendBroadcast(
                Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                    component = info.provider
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                },
            )
        }
    }
}

object WidgetMidnight {
    private const val ACTION_MIDNIGHT = "com.vitalup.app.WIDGET_MIDNIGHT"

    fun schedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            // A minute in, so "today" has surely changed everywhere.
            set(Calendar.MINUTE, 1)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WidgetMidnightReceiver::class.java).setAction(ACTION_MIDNIGHT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pending)
        } catch (e: Exception) {
            // Too many alarms or a restricted device: the 30 minute update remains.
            android.util.Log.w("VitalUp", "Midnight widget update not scheduled: ${e.javaClass.simpleName}")
        }
    }
}
