import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/collections/meal_log_cache.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/features/account/data/account_service.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';
import 'package:vital_up/features/onboarding/data/datasources/shared_preferences_onboarding_data_store.dart';
import 'package:vital_up/features/reminders/data/reminder_scheduler.dart';
import 'package:vital_up/features/reminders/data/reminders_local_datasource.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';

import 'support/fake_backend.dart';
import 'support/test_device.dart';

/// Sign-out on a shared phone, as the app runs it (AuthCubit's
/// beforeSignOut: sync, then AccountService.clearLocalUserData, then the
/// session ends), followed by another account signing in.

const _userA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _userB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class _NoScheduler extends ReminderScheduler {
  _NoScheduler() : super(FlutterLocalNotificationsPlugin());

  @override
  Future<void> cancel(Iterable<int> ids) async {}
}

class _UnusedAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ActivitySession _ride(String id) {
  final start = DateTime.now().subtract(const Duration(hours: 5));
  return ActivitySession(
    id: id,
    activityType: ActivityType.cycle,
    startTime: start,
    endTime: start.add(const Duration(minutes: 40)),
    totalDistanceMeters: 12000,
    totalDurationSeconds: 2400,
    avgPaceSecondsPerKm: 200,
    calories: 400,
    steps: 0,
    stepCountReliable: false,
    points: const [],
  );
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = await initIsarForTests();

  late FakeBackend backend;
  late TestDevice phone;
  late AccountService account;
  late Directory temp;

  setUp(() async {
    if (skip != null) return;
    backend = FakeBackend();
    phone = await TestDevice.create(backend);
    temp = Directory.systemTemp.createTempSync('vitalup_tmp');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => temp.path,
        );
    account = AccountService(
      phone.client,
      _UnusedAuth(),
      RemindersService(
        RemindersLocalDataSource(phone.prefs),
        _NoScheduler(),
        KgSettings(),
      ),
      phone.isarService,
      phone.drift,
      phone.prefs,
      phone.sync,
      phone.cache,
      SharedPreferencesOnboardingDataStore(phone.prefs),
    );
    await phone.signIn(_userA);
  });

  tearDown(() async {
    if (skip != null) return;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await phone.dispose();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// User A's data on the phone: logs in Isar and Drift, a meal photo,
  /// shared files in the cache folder, and per-user preferences.
  Future<File> recordUserA() async {
    await phone.water.addWaterLog(_userA, 350);
    expect(await phone.weight.add(64.0), isNull);
    await phone.activity.saveSession(_ride('ride-1'));
    final photo = File('${temp.path}/meal_photo.jpg')..writeAsBytesSync([1]);
    await phone.isar.writeTxn(
      () => phone.isar.mealLogCaches.put(
        MealLogCache()
          ..mealLogId = 'meal-1'
          ..capturedAt = DateTime.now()
          ..imagePath = photo.path
          ..itemIds = ['f1']
          ..itemNames = ['Dal']
          ..itemConfidences = [0.9]
          ..itemServingDescriptions = ['1 bowl']
          ..itemQuantities = [1]
          ..itemUnits = ['bowl']
          ..nutritionCalories = [180]
          ..nutritionProteinG = [9]
          ..nutritionCarbsG = [25]
          ..nutritionFatG = [4]
          ..nutritionFiberG = [5]
          ..nutritionSugarG = [2]
          ..nutritionSodiumMg = [300]
          ..totalCalories = 180
          ..mealType = 1
          ..userConfirmed = true,
      ),
    );
    Directory('${temp.path}/share_plus').createSync();
    File('${temp.path}/share_plus/export.zip').writeAsBytesSync([1]);
    final prefs = phone.prefs;
    await prefs.setString(
      'vita_chat_$_userA',
      '[{"text":"my blood pressure"}]',
    );
    await prefs.setString('vita_checkins_$_userA', '[]');
    await prefs.setString('onboarding_medicines', 'metformin');
    await prefs.setString('onboarding_allergies', 'peanuts');
    await prefs.setString(
      'activity_annotations',
      '{"ride-1":{"note":"hilly"}}',
    );
    await prefs.setString('active_plan_preferences', '{"diet":"veg"}');
    await prefs.setString('activity_in_progress_v1', '{"id":"ride-1"}');
    await prefs.setString('reminders_v1', '[]');
    // Device settings stay for whoever uses the phone next; goals are the
    // account's (restored from its backup on the next sign-in).
    await prefs.setString('settings_theme_mode', 'dark');
    await prefs.setInt('daily_water_goal', 3000);
    return photo;
  }

  /// What AuthCubit runs before signing out, then the session ends.
  Future<void> signOut() async {
    await phone.sync.sync();
    await account.clearLocalUserData();
    await phone.client.auth.signOut();
  }

  void expectNoUserDataLeft() {
    final keys = phone.prefs.getKeys();
    expect(keys.where((k) => k.startsWith('vita_')), isEmpty);
    expect(keys.where((k) => k.startsWith('onboarding_')), isEmpty);
    expect(keys.where((k) => k.startsWith('sync_cursor_')), isEmpty);
    expect(keys.where((k) => k.startsWith('backup_state_')), isEmpty);
    expect(keys, isNot(contains('sync_pending_deletes')));
    expect(keys, isNot(contains('activity_annotations')));
    expect(keys, isNot(contains('active_plan_preferences')));
    expect(keys, isNot(contains('activity_in_progress_v1')));
    expect(keys, isNot(contains('reminders_v1')));
    expect(phone.prefs.getString('settings_theme_mode'), 'dark');
    expect(phone.prefs.getInt('daily_water_goal'), isNull);
  }

  test(
    'everything is backed up first, then nothing of the user is left',
    () async {
      final photo = await recordUserA();
      final deleted = await phone.water.addWaterLog(_userA, 100);
      await phone.water.deleteWaterLog(deleted.id);
      await eventually(() => backend.count('PATCH user_health_data') == 1);

      await signOut();

      // Backed up before the wipe.
      expect(backend.live('water_logs').map((r) => r['amount_ml']), [350]);
      expect(backend.live('weight_logs'), hasLength(1));
      expect(backend.live('meal_logs'), hasLength(1));
      expect(backend.live('activity_sessions').single['id'], 'ride-1');

      // Wiped from the phone.
      expect(await phone.isar.waterLogCaches.count(), 0);
      expect(await phone.isar.weightLogCaches.count(), 0);
      expect(await phone.isar.mealLogCaches.count(), 0);
      expect(await phone.activity.getSessions(), isEmpty);
      expect(photo.existsSync(), isFalse);
      expect(Directory('${temp.path}/share_plus').existsSync(), isFalse);
      expectNoUserDataLeft();
      expect(phone.prefs.getKeys().where((k) => k.contains(_userA)), isEmpty);
    },
    skip: skip,
  );

  test('the next account on the phone sees only its own data', () async {
    await recordUserA();
    await signOut();

    // User B already has a log from another phone.
    backend.tables['water_logs']!['b-1'] = {
      'id': 'b-1',
      'user_id': _userB,
      'amount_ml': 600,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'deleted_at': null,
    };
    await phone.signIn(_userB);
    await phone.sync.sync(force: true);

    expect((await phone.water.getTodayLogs(_userB)).map((l) => l.amountMl), [
      600,
    ]);
    expect(await phone.water.getTodayLogs(_userA), isEmpty);
    expect(await phone.weight.latest(), isNull);
    expect(await phone.activity.getSessions(), isEmpty);
    // Nothing of A's was uploaded into B's account.
    for (final table in ['water_logs', 'weight_logs', 'activity_sessions']) {
      expect(
        backend.rows(table).where((r) => r['user_id'] == _userB).length,
        table == 'water_logs' ? 1 : 0,
        reason: table,
      );
    }
    expect(phone.writes.countFor(_userB), 0);
  }, skip: skip);

  test(
    'signing out offline ("Sign out anyway") leaves no queued health data',
    () async {
      await phone.network.set(false);
      await recordUserA();
      await eventually(() => phone.writes.countFor(_userA) == 1);
      // Profile shows "Sign out anyway" because of these.
      expect(await phone.sync.pendingCount(), greaterThan(0));

      await signOut();

      expectNoUserDataLeft();
      final queued =
          phone.prefs.getStringList('pending_server_writes_v1') ?? [];
      expect(
        queued
            .map((raw) => jsonDecode(raw) as Map)
            .where((w) => w['user'] == _userA),
        isEmpty,
        reason: "A's queued profile write (weight) is still on the phone",
      );
    },
    skip: skip,
  );
}
