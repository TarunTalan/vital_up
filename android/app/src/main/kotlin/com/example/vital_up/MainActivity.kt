package com.example.vital_up

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Process
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val AUDIO_CHANNEL = "com.example.vital_up/audio_intent"
    private val USAGE_CHANNEL = "com.example.vital_up/usage_stats"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Handler for audio apps & intents
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledAudioApps" -> {
                    val appsList = getInstalledAudioApps()
                    result.success(appsList)
                }
                "launchAudioApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val success = launchAudioApp(packageName)
                        result.success(success)
                    } else {
                        result.error("BAD_ARGS", "Package name is null", null)
                    }
                }
                "playAudioImplicitly" -> {
                    val mediaPath = call.argument<String>("mediaPath") ?: ""
                    val success = playAudioImplicitly(mediaPath)
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Handler for screen usage stats
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> {
                    val hasPermission = checkUsageStatsPermission()
                    result.success(hasPermission)
                }
                "getExactUsageStats" -> {
                    val start = call.argument<Long>("start") ?: 0L
                    val end = call.argument<Long>("end") ?: System.currentTimeMillis()
                    val stats = getExactUsageStats(start, end)
                    result.success(stats)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getInstalledAudioApps(): List<Map<String, String>> {
        val apps = mutableListOf<Map<String, String>>()
        val pm = packageManager

        // Method 1: Query apps that can view audio/* files
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse("content://media/external/audio/media/1"), "audio/*")
        }

        val activities = pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        val packageSet = mutableSetOf<String>()

        for (resolveInfo in activities) {
            val packageName = resolveInfo.activityInfo.packageName
            if (!packageSet.contains(packageName)) {
                packageSet.add(packageName)
                val appLabel = resolveInfo.loadLabel(pm).toString()
                apps.add(mapOf("name" to appLabel, "packageName" to packageName))
            }
        }

        // Method 2: Query standard music category apps
        val musicIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_APP_MUSIC)
        }
        val musicActivities = pm.queryIntentActivities(musicIntent, 0)
        for (resolveInfo in musicActivities) {
            val packageName = resolveInfo.activityInfo.packageName
            if (!packageSet.contains(packageName)) {
                packageSet.add(packageName)
                val appLabel = resolveInfo.loadLabel(pm).toString()
                apps.add(mapOf("name" to appLabel, "packageName" to packageName))
            }
        }

        return apps
    }

    private fun launchAudioApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun playAudioImplicitly(mediaPath: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(mediaPath.ifEmpty { "content://media/external/audio/media/1" }), "audio/*")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(intent, "Play Audio with...")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            true
        } catch (e: Exception) {
            false
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
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
