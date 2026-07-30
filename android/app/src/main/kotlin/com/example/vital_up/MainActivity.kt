package com.example.vital_up

import android.app.AppOpsManager
import android.content.Context
import android.os.Process
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.vital_up/usage_stats"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkUsageStatsPermission") {
                val hasPermission = checkUsageStatsPermission()
                result.success(hasPermission)
            } else if (call.method == "getExactUsageStats") {
                val start = call.argument<Long>("start") ?: 0L
                val end = call.argument<Long>("end") ?: System.currentTimeMillis()
                val stats = getExactUsageStats(start, end)
                result.success(stats)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getExactUsageStats(startTime: Long, endTime: Long): Map<String, Long> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
        val events = usageStatsManager.queryEvents(startTime, endTime)
        val event = android.app.usage.UsageEvents.Event()
        
        val startTimes = HashMap<String, Long>()
        val totalUsage = HashMap<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName
            val time = event.timeStamp
            
            if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND || event.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED) {
                startTimes[packageName] = time
            } else if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_BACKGROUND || event.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED) {
                val start = startTimes[packageName]
                if (start != null) {
                    val duration = time - start
                    val currentTotal = totalUsage[packageName] ?: 0L
                    totalUsage[packageName] = currentTotal + duration
                    startTimes.remove(packageName)
                }
            }
        }
        
        // Handle apps still open
        val endCap = Math.min(System.currentTimeMillis(), endTime)
        for ((packageName, start) in startTimes) {
            val duration = endCap - start
            if (duration > 0) {
               val currentTotal = totalUsage[packageName] ?: 0L
               totalUsage[packageName] = currentTotal + duration
            }
        }

        return totalUsage
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION.SDK_INT) {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                "android:get_usage_stats",
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
