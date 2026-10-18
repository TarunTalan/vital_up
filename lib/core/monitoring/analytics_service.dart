import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized analytics service powered by Firebase Analytics.
///
/// Designed to fail gracefully if Firebase is not configured or in debug/test mode.
abstract final class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;
  static bool _enabled = false;
  static String? _userId;

  /// Same key as `SettingsLocalDataSourceImpl.keyAnalyticsEnabled` (core
  /// can't import a feature).
  static const _prefKey = 'settings_analytics_enabled';

  /// Returns the GoRouter / Navigator observer for automatic screen tracking.
  static NavigatorObserver get observer {
    if (_observer != null) return _observer!;
    try {
      final analytics = _analytics ?? FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: analytics);
      return _observer!;
    } catch (_) {
      // Fallback dummy observer when Firebase is not configured
      return NavigatorObserver();
    }
  }

  /// Initializes Firebase Analytics and configures data collection.
  static Future<void> init() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      // Off in debug; otherwise the user's choice in Settings (default on).
      final prefs = await SharedPreferences.getInstance();
      _enabled = !kDebugMode && (prefs.getBool(_prefKey) ?? true);
      await _analytics!.setAnalyticsCollectionEnabled(_enabled);
      debugPrint(
        '[AnalyticsService] Firebase Analytics initialized (enabled: $_enabled)',
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Disabled, Firebase not configured: $e');
      _enabled = false;
    }
  }

  /// Settings > Privacy switch. Turning it off also clears the user id and
  /// the data collected on this device so far.
  static Future<void> setEnabled(bool enabled) async {
    final analytics = _analytics;
    final on = enabled && !kDebugMode;
    if (analytics == null || on == _enabled) return;
    _enabled = on;
    try {
      await analytics.setAnalyticsCollectionEnabled(on);
      if (on) {
        await analytics.setUserId(id: _userId);
      } else {
        await analytics.setUserId(id: null);
        await analytics.resetAnalyticsData();
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Could not apply the setting: $e');
    }
  }

  /// Links the pseudonymous account id (no email or name) while enabled.
  static void watchUser(SupabaseClient client) {
    if (_analytics == null) return;
    client.auth.onAuthStateChange
        // A token refresh that fails offline arrives as an error; not a crash.
        .handleError((Object _) {})
        .listen((auth) {
          _userId = auth.session?.user.id;
          if (_enabled) _analytics?.setUserId(id: _userId);
        });
  }

  /// Sets custom user properties (e.g., subscription tier, onboarding status).
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_enabled || _analytics == null) return;
    try {
      await _analytics!.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting user property $name: $e');
    }
  }

  /// Logs a custom event with optional parameters.
  ///
  /// Never pass health figures (weights, calories, water, sleep, mood,
  /// workouts, food names), free text or Health Connect data: the privacy
  /// policy and Health Connect rules forbid them in analytics.
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_enabled || _analytics == null) {
      debugPrint('[AnalyticsService Mock] Event: $name | Params: $parameters');
      return;
    }
    try {
      await _analytics!.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging event $name: $e');
    }
  }

  /// Logs explicit screen view transitions.
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_enabled || _analytics == null) return;
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      debugPrint(
        '[AnalyticsService] Error logging screen view $screenName: $e',
      );
    }
  }
}
