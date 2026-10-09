package com.tarun_siddhi.vital_up

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val AUDIO_CHANNEL = "com.example.vital_up/audio_intent"
    private val USAGE_CHANNEL = "com.example.vital_up/usage_stats"

    /** Usage queries can take a while on busy phones: keep them off the UI thread. */
    private val usageExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onDestroy() {
        usageExecutor.shutdown()
        super.onDestroy()
    }

    /** Epoch millis from Dart (an int arrives as Integer or Long). */
    private fun MethodCall.millis(key: String): Long? =
        (argument<Any>(key) as? Number)?.toLong()

    /**
     * [start, end] from the call, clamped to something sane: not in the
     * future, start before end, at most [MAX_RANGE_MS] long.
     */
    private fun MethodCall.timeRange(): Pair<Long, Long>? {
        val now = System.currentTimeMillis()
        val end = (millis("end") ?: now).coerceIn(0L, now)
        val start = (millis("start") ?: 0L).coerceAtLeast(end - MAX_RANGE_MS).coerceAtLeast(0L)
        return if (start < end) start to end else null
    }

    /** Runs [work] in the background and answers on the main thread; never throws across the channel. */
    private fun answerInBackground(result: MethodChannel.Result, work: () -> Any?) {
        try {
            usageExecutor.execute {
                val outcome = try {
                    Result.success(work())
                } catch (e: Exception) {
                    Log.w(TAG, "Usage query failed", e)
                    Result.failure(e)
                }
                mainHandler.post {
                    outcome.fold(
                        onSuccess = { result.success(it) },
                        onFailure = { result.error("UNAVAILABLE", "Usage data is unavailable.", null) },
                    )
                }
            }
        } catch (e: Exception) {
            // Executor already shut down (activity finishing).
            result.error("UNAVAILABLE", "Usage data is unavailable.", null)
        }
    }

    companion object {
        private const val TAG = "VitalUpMain"
        private const val MAX_RANGE_MS = 31L * 24 * 60 * 60 * 1000
        private val PACKAGE_NAME = Regex("^[A-Za-z][A-Za-z0-9_]*([.][A-Za-z0-9_]+)+$")
        private val ALLOWED_MEDIA_SCHEMES = setOf("content", "http", "https")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Handler for audio apps & intents
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledAudioApps" -> {
                    val appsList = try {
                        getInstalledAudioApps()
                    } catch (e: Exception) {
                        Log.w(TAG, "Listing audio apps failed", e)
                        emptyList<Map<String, String>>()
                    }
                    result.success(appsList)
                }
                "launchAudioApp" -> {
                    val packageName = call.argument<Any>("packageName") as? String
                    if (packageName != null && packageName.length <= 255 && PACKAGE_NAME.matches(packageName)) {
                        result.success(launchAudioApp(packageName))
                    } else {
                        result.error("BAD_ARGS", "A valid package name is required.", null)
                    }
                }
                "playAudioImplicitly" -> {
                    val mediaPath = (call.argument<Any>("mediaPath") as? String).orEmpty()
                    result.success(playAudioImplicitly(mediaPath))
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
                    result.success(checkUsageStatsPermission())
                }
                "getExactUsageStats" -> {
                    val range = call.timeRange()
                    if (range == null || !checkUsageStatsPermission()) {
                        result.success(emptyMap<String, Long>())
                    } else {
                        answerInBackground(result) { getExactUsageStats(range.first, range.second) }
                    }
                }
                "getScreenEvents" -> {
                    val range = call.timeRange()
                    if (range == null) {
                        result.success(emptyList<Map<String, Any>>())
                    } else {
                        answerInBackground(result) { getScreenEvents(range.first, range.second) }
                    }
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
            // Only shareable URIs: a file:// path would crash on Android 7+.
            val parsed = mediaPath.takeIf { it.isNotBlank() && it.length <= 2048 }?.let { Uri.parse(it) }
            val uri = if (parsed != null && parsed.scheme?.lowercase() in ALLOWED_MEDIA_SCHEMES) {
                parsed
            } else {
                Uri.parse("content://media/external/audio/media/1")
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "audio/*")
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
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? android.app.usage.UsageStatsManager
            ?: return emptyMap()
        val events = usageStatsManager.queryEvents(startTime, endTime) ?: return emptyMap()
        val event = android.app.usage.UsageEvents.Event()

        val startTimes = HashMap<String, Long>()
        val totalUsage = HashMap<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
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

    /**
     * Screen on/off times in [startTime, endTime], oldest first, as
     * {"t": epochMillis, "on": Boolean}. Used to estimate sleep from the
     * longest screen-off stretch. Needs Android 9 (API 28); empty before.
     */
    private fun getScreenEvents(startTime: Long, endTime: Long): List<Map<String, Any>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P || !checkUsageStatsPermission()) {
            return emptyList()
        }
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? android.app.usage.UsageStatsManager
            ?: return emptyList()
        val events = usageStatsManager.queryEvents(startTime, endTime) ?: return emptyList()
        val event = android.app.usage.UsageEvents.Event()
        val out = mutableListOf<Map<String, Any>>()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                android.app.usage.UsageEvents.Event.SCREEN_INTERACTIVE ->
                    out.add(mapOf("t" to event.timeStamp, "on" to true))
                android.app.usage.UsageEvents.Event.SCREEN_NON_INTERACTIVE ->
                    out.add(mapOf("t" to event.timeStamp, "on" to false))
            }
        }
        return out
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        return try {
            @Suppress("DEPRECATION")
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }
}
