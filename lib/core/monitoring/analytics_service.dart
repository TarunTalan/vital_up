import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized analytics service powered by Firebase Analytics.
///
/// Designed to fail gracefully if Firebase is not configured or in debug/test mode.
abstract final class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;
  static bool _enabled = false;

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
      // Enable collection in release / profile mode, disable in debug
      _enabled = !kDebugMode;
      await _analytics!.setAnalyticsCollectionEnabled(_enabled);
      debugPrint(
        '[AnalyticsService] Firebase Analytics initialized (enabled: $_enabled)',
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Disabled, Firebase not configured: $e');
      _enabled = false;
    }
  }

  /// Links authenticated user id to analytics without collecting PII.
  static void watchUser(SupabaseClient client) {
    if (!_enabled || _analytics == null) return;
    client.auth.onAuthStateChange
        // A token refresh that fails offline arrives as an error; not a crash.
        .handleError((Object _) {})
        .listen((auth) {
          final userId = auth.session?.user.id;
          _analytics?.setUserId(id: userId);
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

  // ===========================================================================
  // Domain Event Shortcuts
  // ===========================================================================

  /// Track workout completion.
  static Future<void> logWorkoutCompleted({
    required String activityType,
    required int durationSeconds,
    required double distanceMeters,
    required int calories,
  }) async {
    await logEvent(
      'workout_completed',
      parameters: {
        'activity_type': activityType,
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters.round(),
        'calories': calories,
      },
    );
  }

  /// Track food scanning actions.
  static Future<void> logFoodScanned({
    required String scanType, // barcode | nutrition_label | camera_food
    required bool success,
    String? foodName,
  }) async {
    final params = <String, Object>{
      'scan_type': scanType,
      'success': success ? 1 : 0,
    };
    if (foodName != null) {
      params['food_name'] = foodName;
    }
    await logEvent('food_scanned', parameters: params);
  }

  /// Track water logging.
  static Future<void> logWaterIntake({required int amountMl}) async {
    await logEvent('water_logged', parameters: {'amount_ml': amountMl});
  }

  /// Track AI coach interaction.
  static Future<void> logVitaInteraction({
    required String interactionType,
  }) async {
    await logEvent('vita_interaction', parameters: {'type': interactionType});
  }

  /// Track badge unlock or challenge completion.
  static Future<void> logAchievementUnlocked({
    required String achievementId,
    required String type, // badge | challenge
  }) async {
    await logEvent(
      'achievement_unlocked',
      parameters: {'achievement_id': achievementId, 'achievement_type': type},
    );
  }
}
