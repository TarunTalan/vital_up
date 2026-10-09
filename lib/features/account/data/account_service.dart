import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';
import 'package:vital_up/core/sync/sync_service.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_history_repository_impl.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';
import 'package:vital_up/features/diet_plan/data/repositories/diet_plan_repository_impl.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';

/// Permanently deletes the signed-in user's account (server: the
/// `delete-account` Edge Function) and everything stored on this device.
class AccountService {
  final SupabaseClient _client;
  final AuthRepository _auth;
  final RemindersService _reminders;
  final IsarService _isar;
  final AppDatabase _drift;
  final SharedPreferences _prefs;
  final SyncService _sync;
  final CacheStore _cache;

  AccountService(
    this._client,
    this._auth,
    this._reminders,
    this._isar,
    this._drift,
    this._prefs,
    this._sync,
    this._cache,
  );

  static const _deleteFailed = "Couldn't delete your account. Try again.";

  /// Null on success, otherwise a message to show.
  Future<String?> deleteAccount() async {
    try {
      if (_client.auth.currentUser == null) return 'Please sign in again.';
      final response = await _client.functions
          .invoke('delete-account')
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      if (data is! Map || data['deleted'] != true) {
        debugPrint('Account deletion refused: $data');
        return _deleteFailed;
      }
    } on FunctionException catch (e) {
      CrashReporter.report(e, StackTrace.current, reason: 'Account deletion');
      return userMessage(e, fallback: _deleteFailed);
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      return userMessage(e, fallback: _deleteFailed);
    }

    // The account is gone; from here on, clean up as much as possible.
    await wipeDevice();
    return null;
  }

  /// Removes the signed-in user's logs, workouts and reminders from this
  /// device (sign-out). Settings and goals stay.
  Future<void> clearLocalUserData() async {
    await _step('reminders', _reminders.clear);
    await _step('isar', _isar.clearUserData);
    await _step('drift', _drift.clearAll);
    await _step('sync state', _sync.reset);
    await _step('server cache', _cache.clear);
    // Backed up per account and restored on the next sign-in; leaving them
    // would hand this user's notes and plan to the next account here.
    await _step('workout notes', () async {
      await _prefs.remove(ActivityHistoryRepositoryImpl.annotationsKey);
    });
    await _step('diet plan preferences', () async {
      await _prefs.remove(DietPlanRepositoryImpl.preferencesKey);
    });
  }

  /// Removes every trace of the user from this device and signs out.
  Future<void> wipeDevice() async {
    await clearLocalUserData();
    await _step('preferences', _prefs.clear);
    await _step(
      'session',
      () => _client.auth.signOut(scope: SignOutScope.local),
    );
    await _step('auth', () async => _auth.signOut());
  }

  static Future<void> _step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      debugPrint('Wipe step "$name" failed: $e');
    }
  }
}
