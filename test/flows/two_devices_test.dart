import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/sync/backup_sync.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

import 'support/fake_backend.dart';
import 'support/test_device.dart';

/// One account on two phones sharing the (fake) backend: what one phone
/// records, deletes or changes in its settings shows up on the other.

const _user = '22222222-2222-4222-8222-222222222222';

List<BackupSource> _backups(SharedPreferences prefs) => [
  PrefsBackupSource('settings', prefs, [
    'settings_theme_mode',
    'settings_weight_unit',
  ]),
  PrefsBackupSource('goals', prefs, [
    'daily_water_goal',
    'daily_sleep_goal_min',
  ]),
];

ActivitySession _walk(String id) {
  final start = DateTime.now().subtract(const Duration(hours: 3));
  return ActivitySession(
    id: id,
    activityType: ActivityType.walk,
    startTime: start,
    endTime: start.add(const Duration(minutes: 20)),
    totalDistanceMeters: 1500,
    totalDurationSeconds: 1200,
    avgPaceSecondsPerKm: 800,
    calories: 90,
    steps: 2000,
    stepCountReliable: true,
    points: const [],
  );
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = await initIsarForTests();

  late FakeBackend backend;
  late TestDevice phoneA;
  late TestDevice phoneB;

  setUp(() async {
    if (skip != null) return;
    backend = FakeBackend();
    phoneA = await TestDevice.create(backend, backups: _backups);
    phoneB = await TestDevice.create(backend, backups: _backups);
    await phoneA.signIn(_user);
    await phoneB.signIn(_user);
  });

  tearDown(() async {
    if (skip != null) return;
    await phoneA.dispose();
    await phoneB.dispose();
  });

  test('logs from one phone show on the other, without re-uploads', () async {
    await phoneA.water.addWaterLog(_user, 400);
    expect(await phoneA.weight.add(80.2), isNull);
    await phoneA.activity.saveSession(_walk('walk-1'));
    await phoneA.sync.sync(force: true);

    await phoneB.sync.sync(force: true);
    final water = await phoneB.water.getTodayLogs(_user);
    expect(water.map((l) => l.amountMl), [400]);
    expect((await phoneB.weight.latest())?.weightKg, 80.2);
    expect((await phoneB.activity.getSessions()).single.id, 'walk-1');

    // Pulled rows count as backed up: phone B uploads none of them.
    expect(await phoneB.sync.pendingCount(), 0);
    final posts = backend.requests.length;
    await phoneB.sync.sync(force: true);
    expect(
      backend.requests
          .skip(posts)
          .where((r) => r.startsWith('POST') && r != 'POST user_backups'),
      isEmpty,
    );
  }, skip: skip);

  test('a delete on one phone removes the entry on the other', () async {
    final log = await phoneA.water.addWaterLog(_user, 250);
    await phoneA.water.addWaterLog(_user, 500);
    await phoneA.activity.saveSession(_walk('walk-2'));
    await phoneA.sync.sync(force: true);
    await phoneB.sync.sync(force: true);
    expect(await phoneB.water.getTodayLogs(_user), hasLength(2));

    await phoneA.water.deleteWaterLog(log.id);
    await phoneA.activity.deleteSession('walk-2');
    await phoneA.sync.sync(force: true);
    expect(backend.live('water_logs'), hasLength(1));
    expect(backend.live('activity_sessions'), isEmpty);

    await phoneB.sync.sync(force: true);
    final left = await phoneB.water.getTodayLogs(_user);
    expect(left.map((l) => l.amountMl), [500]);
    expect(await phoneB.activity.getSessions(), isEmpty);
  }, skip: skip);

  test('a new phone receives the backup instead of overwriting it', () async {
    await phoneA.prefs.setInt('daily_water_goal', 3200);
    await phoneA.prefs.setString('settings_weight_unit', 'lbs');
    await phoneA.sync.sync(force: true);

    // Phone B still has its untouched defaults.
    await phoneB.prefs.setInt('daily_water_goal', 2500);
    await phoneB.sync.sync(force: true);

    expect(phoneB.prefs.getInt('daily_water_goal'), 3200);
    expect(phoneB.prefs.getString('settings_weight_unit'), 'lbs');
    final goals = backend
        .rows('user_backups')
        .firstWhere((r) => r['kind'] == 'goals');
    expect((goals['data'] as Map)['daily_water_goal'], 3200);
  }, skip: skip);

  test('different goals changed on both phones are both kept', () async {
    await phoneA.prefs.setInt('daily_water_goal', 2500);
    await phoneA.prefs.setInt('daily_sleep_goal_min', 480);
    await phoneA.sync.sync(force: true);
    await phoneB.sync.sync(force: true);
    expect(phoneB.prefs.getInt('daily_sleep_goal_min'), 480);

    // Edited on both phones before either syncs again.
    await phoneA.prefs.setInt('daily_water_goal', 3000);
    await phoneB.prefs.setInt('daily_sleep_goal_min', 420);
    await phoneA.sync.sync(force: true);
    await phoneB.sync.sync(force: true);
    await phoneA.sync.sync(force: true);

    for (final phone in [phoneA, phoneB]) {
      expect(phone.prefs.getInt('daily_water_goal'), 3000);
      expect(phone.prefs.getInt('daily_sleep_goal_min'), 420);
    }
    final goals = backend
        .rows('user_backups')
        .firstWhere((r) => r['kind'] == 'goals');
    expect(goals['data'], {
      'daily_water_goal': 3000,
      'daily_sleep_goal_min': 420,
    });
  }, skip: skip);
}
