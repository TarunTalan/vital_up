import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';
import 'package:vital_up/core/sync/sync_service.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_history_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_recovery_service.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_notification.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';
import 'package:vital_up/features/diet_plan/data/repositories/diet_plan_repository_impl.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_data_store.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_bedtime.dart';
import 'package:vital_up/features/health_sync/health_import_service.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

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
  final OnboardingDataStore? _onboarding;
  final WorkoutTimerNotifier? _workoutTimer;

  AccountService(
    this._client,
    this._auth,
    this._reminders,
    this._isar,
    this._drift,
    this._prefs,
    this._sync,
    this._cache, [
    this._onboarding,
    this._workoutTimer,
  ]);

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

  /// Personal goals (backed up per account as `goals`, restored on the next
  /// sign-in). Cleared on sign-out so the next account here starts from
  /// defaults instead of inheriting (and uploading) them.
  static const goalKeys = [
    'activity_goals_v1',
    'daily_water_goal',
    'daily_sleep_goal_min',
    'daily_screen_time_limit_min',
  ];

  /// Removes the signed-in user's logs, workouts, goals and reminders from
  /// this device (sign-out). Settings (theme, units...) stay.
  Future<void> clearLocalUserData() async {
    // First: a sync still running must not write rows back after the wipe.
    await _step('sync', _sync.stop);
    await _step('reminders', _reminders.clear);
    // Before Isar is cleared: the meal rows hold the photo paths.
    await _step('meal photos', _deleteMealPhotos);
    await _step('isar', _isar.clearUserData);
    await _step('drift', _drift.clearAll);
    await _step('sync state', _sync.reset);
    await _step('server cache', _cache.clear);
    // Backed up per account and restored on the next sign-in; leaving them
    // would hand this user's notes and plan to the next account here.
    await _step('workout notes', () async {
      await _prefs.remove(ActivityHistoryRepositoryImpl.annotationsKey);
    });
    await _step('goals', () async {
      for (final key in goalKeys) {
        await _prefs.remove(key);
      }
    });
    await _step('diet plan preferences', () async {
      await _prefs.remove(DietPlanRepositoryImpl.preferencesKey);
    });
    // Health answers (age, medicines, allergies...) Vita falls back on;
    // the next account here must never inherit them.
    await _step('onboarding answers', () async {
      await _onboarding?.clearOnboardingData();
    });
    // Points at a workout that was just wiped with the rest of Drift.
    await _step('workout in progress', () async {
      await _prefs.remove(WorkoutCheckpointStore.key);
      await _prefs.remove(WorkoutTimerStore.key);
      await _workoutTimer?.cancel();
    });
    // Vita chats, check-ins, scores and insights are keyed by user, but the
    // health details in them must not stay on a shared phone.
    await _step('vita history', () async {
      for (final key in _prefs.getKeys().where(isVitaUserKey).toList()) {
        await _prefs.remove(key);
      }
    });
    // Goal weight (old device-wide key), "in bed" taps and the Health
    // Connect import mark: the next account must start from its own.
    await _step('other per-user values', () async {
      await _prefs.remove(WeightService.legacyTargetKey);
      await _prefs.remove(HealthImportService.lastImportKey);
      for (final key in _prefs
          .getKeys()
          .where((k) => k.startsWith(bedtimeKey('')))
          .toList()) {
        await _prefs.remove(key);
      }
    });
    // Camera / picker photos, exports and health reports shared from here.
    await _step('temporary files', _deleteTemporaryFiles);
    // Wiped: whoever signs in next starts clean without another wipe.
    await _step('device owner', () async {
      await _prefs.remove(deviceOwnerKey);
    });
  }

  /// The account whose data is on this device.
  static const deviceOwnerKey = 'local_data_owner_id';

  /// Called on sign-in before the first sync. If another account's data
  /// is still here (sign-out was cut short, the app was killed during it,
  /// or the session simply expired), it is wiped first: otherwise this
  /// account would show it and upload it as its own.
  Future<void> claimDevice(String userId) async {
    final owner = _prefs.getString(deviceOwnerKey);
    if (owner == userId) return;
    if (owner != null) {
      debugPrint("Another account's data was on this device; clearing it.");
      await clearLocalUserData();
    }
    await _prefs.setString(deviceOwnerKey, userId);
  }

  /// Per-user Vita history keys (`vita_<name>_<userId>`).
  @visibleForTesting
  static bool isVitaUserKey(String key) =>
      RegExp(r'^vita_(chat|checkins|scores|insights)_').hasMatch(key);

  Future<void> _deleteMealPhotos() async {
    final paths = await _isar.isar.mealLogCaches
        .where()
        .imagePathProperty()
        .findAll();
    for (final path in paths.where((p) => p.isNotEmpty)) {
      await _deleteFile(File(path));
    }
  }

  /// Files at the top of the cache folder (camera and image picker photos,
  /// the data export, health reports) and share_plus's copies of them.
  static Future<void> _deleteTemporaryFiles() async {
    final dir = await getTemporaryDirectory();
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        await _deleteFile(entity);
      } else if (entity is Directory &&
          entity.path.split(Platform.pathSeparator).last == 'share_plus') {
        await entity.delete(recursive: true);
      }
    }
  }

  static Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Could not delete a local file: $e');
    }
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
