import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends uncaught errors to Firebase Crashlytics in release builds.
///
/// A no-op (errors are only printed) until Firebase is configured or in
/// debug builds.
abstract final class CrashReporter {
  static bool _enabled = false;

  /// Call first thing in `main`, after `WidgetsFlutterBinding`.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Crash reporting disabled, Firebase is not configured: $e');
      return;
    }
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    _enabled = !kDebugMode;

    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Tags reports with the signed-in user's id (never email or name).
  static void watchUser(SupabaseClient client) {
    if (!_enabled) return;
    client.auth.onAuthStateChange.listen((auth) {
      FirebaseCrashlytics.instance.setUserIdentifier(
        auth.session?.user.id ?? '',
      );
    });
  }

  /// Reports a handled error worth knowing about.
  static void report(Object error, StackTrace? stack, {String? reason}) {
    debugPrint('${reason ?? 'Error'}: $error');
    if (!_enabled) return;
    FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
  }
}
