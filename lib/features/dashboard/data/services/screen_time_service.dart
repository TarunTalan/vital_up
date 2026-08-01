import 'dart:async';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../../domain/entities/app_usage_info.dart';

class ScreenTimeService {
  static const MethodChannel _channel = MethodChannel('com.example.vital_up/usage_stats');
  
  // App Usage Filtering
  static const List<String> _ignoredPackages = [
    'launcher', 'systemui', 'incallui', 'com.android.settings', 
    'com.android.providers', 'com.google.android.gms', 
    'com.android.vending', 'com.sec.android.app',
    'com.miui', 'com.samsung.android', 'com.google.android.permissioncontroller',
    'com.android.permissioncontroller', 'com.google.android.setupwizard',
    'com.google.android.apps.wellbeing', 'com.android.server.telecom',
    'com.google.android.as', 'android.uid.system', 'com.android.server'
  ];

  static const Map<String, String> _appNameMappings = {
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
    'com.twitter.android': 'X (Twitter)',
    'com.facebook.katana': 'Facebook',
    'com.snapchat.android': 'Snapchat',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.google.android.apps.messaging': 'Messages',
    'com.google.android.dialer': 'Phone',
    'com.google.android.contacts': 'Contacts',
    'com.google.android.gm': 'Gmail',
    'com.android.chrome': 'Chrome',
    'com.spotify.music': 'Spotify',
    'com.netflix.mediaclient': 'Netflix',
    'org.telegram.messenger': 'Telegram',
    'com.linkedin.android': 'LinkedIn',
    'com.reddit.frontpage': 'Reddit',
    'com.discord': 'Discord'
  };

  Future<bool> hasPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('checkUsageStatsPermission');
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  Future<void> openSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.USAGE_ACCESS_SETTINGS',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  Future<List<AppUsageInfo>> getUsageStats() async {
    try {
      final endDate = DateTime.now();
      final startDate = DateTime(endDate.year, endDate.month, endDate.day); // Today exactly at midnight local time

      final List<AppUsageInfo> infoList = [];
      final List<AppUsageInfo> usage = await _fetchAppUsage(startDate, endDate);
      
      for (var info in usage) {
        if (info.usageDuration.inMinutes > 0) {
          infoList.add(info);
        }
      }
      
      // Sort descending
      infoList.sort((a, b) => b.usageDuration.compareTo(a.usageDuration));
      return infoList;
    } catch (e) {
      throw Exception('Failed to get usage stats: $e');
    }
  }
  
  Future<List<AppUsageInfo>> _fetchAppUsage(DateTime startDate, DateTime endDate) async {
    try {
      final Map<dynamic, dynamic>? rawStats = await _channel.invokeMethod('getExactUsageStats', {
        'start': startDate.millisecondsSinceEpoch,
        'end': endDate.millisecondsSinceEpoch
      });
      
      if (rawStats == null) return [];
      
      List<AppUsageInfo> result = [];
      
      rawStats.forEach((key, value) {
        final pkg = key.toString().toLowerCase();
        final durationMillis = (value as num).toInt();
        
        // Skip system packages
        if (_ignoredPackages.any((ignore) => pkg.contains(ignore))) {
          return; // continue in forEach
        }

        // Apply robust naming map
        String resolvedName = _appNameMappings[key.toString()] ?? key.toString();
        
        // Fallback cleaner
        if (resolvedName == key.toString()) {
          final parts = resolvedName.split('.');
          resolvedName = parts.last;
          if (resolvedName.isNotEmpty) {
            resolvedName = resolvedName[0].toUpperCase() + resolvedName.substring(1);
          }
        }

        result.add(AppUsageInfo(
          appName: resolvedName,
          packageName: key.toString(),
          usageDuration: Duration(milliseconds: durationMillis),
        ));
      });
      
      return result;
    } catch (exception) {
      throw Exception('Failed to get exact app usage: $exception');
    }
  }
}
