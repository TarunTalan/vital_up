import 'dart:isolate';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends uncaught errors to Firebase Crashlytics in release builds.
///
/// Handles Flutter UI errors, asynchronous platform dispatcher errors,
/// and background isolate uncaught exceptions (GPS, pedometer, Health Connect).
abstract final class CrashReporter {
  static bool _enabled = false;
  static RawReceivePort? _isolateErrorPort;

  /// Call first thing in `main`, after `WidgetsFlutterBinding`.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Crash reporting disabled, Firebase is not configured: $e');
      _hookLocalErrorHandlers();
      return;
    }

    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    _enabled = !kDebugMode;

    // 1. Flutter framework UI build & render errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_enabled) {
        crashlytics.recordFlutterFatalError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    // 2. Asynchronous platform dispatcher errors (outside Flutter widget tree)
    PlatformDispatcher.instance.onError = (error, stack) {
      if (_enabled) {
        crashlytics.recordError(error, stack, fatal: true);
      } else {
        debugPrint('PlatformDispatcher uncaught error: $error\n$stack');
      }
      return true;
    };

    // 3. Catch unhandled errors from the root isolate and background isolates
    hookCurrentIsolate();
  }

  static void _hookLocalErrorHandlers() {
    FlutterError.onError = FlutterError.presentError;
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher uncaught error: $error\n$stack');
      return true;
    };
    hookCurrentIsolate();
  }

  /// Registers an error listener on the given isolate or current isolate.
  /// Useful for background isolates (e.g., GPS tracking, pedometer streams, Health Connect).
  static void hookCurrentIsolate() {
    try {
      _isolateErrorPort?.close();
      _isolateErrorPort = RawReceivePort((pair) async {
        final List<dynamic> errorAndStacktrace = pair as List<dynamic>;
        final error = errorAndStacktrace.isNotEmpty ? errorAndStacktrace[0] : 'Unknown isolate error';
        final rawStack = errorAndStacktrace.length > 1 ? errorAndStacktrace[1] : null;
        final stackTrace = rawStack != null
            ? (rawStack is StackTrace ? rawStack : StackTrace.fromString(rawStack.toString()))
            : StackTrace.current;

        debugPrint('Unhandled Isolate Error: $error\n$stackTrace');
        if (_enabled) {
          await FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            reason: 'Unhandled isolate error',
            fatal: true,
          );
        }
      });

      Isolate.current.addErrorListener(_isolateErrorPort!.sendPort);
    } catch (e) {
      debugPrint('Failed to attach isolate error listener: $e');
    }
  }

  /// Listens to errors on a spawned background isolate.
  static void hookIsolate(Isolate isolate) {
    try {
      final port = RawReceivePort((pair) async {
        final List<dynamic> errorAndStacktrace = pair as List<dynamic>;
        final error = errorAndStacktrace.isNotEmpty ? errorAndStacktrace[0] : 'Unknown background isolate error';
        final rawStack = errorAndStacktrace.length > 1 ? errorAndStacktrace[1] : null;
        final stackTrace = rawStack != null
            ? (rawStack is StackTrace ? rawStack : StackTrace.fromString(rawStack.toString()))
            : StackTrace.current;

        debugPrint('Unhandled Background Isolate Error: $error\n$stackTrace');
        if (_enabled) {
          await FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            reason: 'Background isolate error',
            fatal: true,
          );
        }
      });
      isolate.addErrorListener(port.sendPort);
    } catch (e) {
      debugPrint('Failed to hook background isolate: $e');
    }
  }

  /// Sets a custom key-value pair for Crashlytics diagnostics.
  static void setCustomKey(String key, Object value) {
    if (!_enabled) return;
    FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  /// Adds a breadcrumb log entry to Crashlytics reports.
  static void log(String message) {
    debugPrint('[CrashReporter] $message');
    if (!_enabled) return;
    FirebaseCrashlytics.instance.log(message);
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
  static void report(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    debugPrint('${reason ?? 'Error'}: $error');
    if (!_enabled) return;
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }
}
