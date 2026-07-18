import 'dart:async';
import 'dart:io';
import 'package:app_usage/app_usage.dart' as app_usage_pkg;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../../domain/entities/app_usage_info.dart';

class ScreenTimeService with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('com.example.vital_up/usage_stats');
  
  // iOS fallback tracking
  DateTime? _appResumedTime;
  Duration _iosForegroundDuration = Duration.zero;

  ScreenTimeService() {
    if (Platform.isIOS) {
      WidgetsBinding.instance.addObserver(this);
      _appResumedTime = DateTime.now();
    }
  }

  void dispose() {
    if (Platform.isIOS) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!Platform.isIOS) return;

    if (state == AppLifecycleState.resumed) {
      _appResumedTime = DateTime.now();
    } else if (state == AppLifecycleState.paused) {
      if (_appResumedTime != null) {
        _iosForegroundDuration += DateTime.now().difference(_appResumedTime!);
        _appResumedTime = null;
      }
    }
  }

  Future<bool> hasPermission() async {
    if (Platform.isIOS) return true; // In-app tracking needs no special permission
    try {
      final bool hasPermission = await _channel.invokeMethod('checkUsageStatsPermission');
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  Future<void> openSettings() async {
    if (!Platform.isIOS) {
      const intent = AndroidIntent(
        action: 'android.settings.USAGE_ACCESS_SETTINGS',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    }
  }

  Future<List<AppUsageInfo>> getUsageStats() async {
    if (Platform.isIOS) {
      // Calculate current session duration if still in foreground
      Duration totalDuration = _iosForegroundDuration;
      if (_appResumedTime != null) {
        totalDuration += DateTime.now().difference(_appResumedTime!);
      }
      
      return [
        AppUsageInfo(
          appName: 'VitalUp (In-App)',
          packageName: 'com.example.vital_up',
          usageDuration: totalDuration,
        )
      ];
    }

    try {
      final endDate = DateTime.now();
      final startDate = DateTime(endDate.year, endDate.month, endDate.day); // Today

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
      List<AppUsageInfo> result = await app_usage_pkg.AppUsage().getAppUsage(startDate, endDate).then((infos) {
          return infos.map((i) {
            String resolvedName = i.appName;
            if (i.packageName == 'com.instagram.android') resolvedName = 'Instagram';
            
            return AppUsageInfo(
              appName: resolvedName,
              packageName: i.packageName,
              usageDuration: i.usage,
            );
          }).toList();
      });
      return result;
    } catch (exception) {
      throw Exception('Failed to get app usage: $exception');
    }
  }
}
