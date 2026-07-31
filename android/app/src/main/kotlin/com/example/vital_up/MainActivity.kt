package com.example.vital_up

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.vital_up/audio_intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
}
