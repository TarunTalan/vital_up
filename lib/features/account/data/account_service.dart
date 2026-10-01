import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';
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

  AccountService(
    this._client,
    this._auth,
    this._reminders,
    this._isar,
    this._drift,
    this._prefs,
  );

  /// Null on success, otherwise a message to show.
  Future<String?> deleteAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      final data = response.data;
      if (data is! Map || data['deleted'] != true) {
        return 'Could not delete your account. Try again.';
      }
    } on FunctionException catch (e) {
      CrashReporter.report(e, StackTrace.current, reason: 'Account deletion');
      return 'Could not delete your account. Try again.';
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      return 'Could not reach the server. Check your connection and try again.';
    }

    // The account is gone; from here on, clean up as much as possible.
    await wipeDevice();
    return null;
  }

  /// Removes every trace of the user from this device and signs out.
  Future<void> wipeDevice() async {
    Future<void> step(String name, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        debugPrint('Wipe step "$name" failed: $e');
      }
    }

    await step('reminders', _reminders.clear);
    await step('isar', _isar.clearUserData);
    await step('drift', _drift.clearAll);
    await step('preferences', _prefs.clear);
    await step(
      'session',
      () => _client.auth.signOut(scope: SignOutScope.local),
    );
    await step('auth', () async => _auth.signOut());
  }
}
