import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';

import 'support/fake_backend.dart';
import 'support/test_device.dart';

/// Logging with no network, then coming back online: everything recorded
/// offline (logs, a workout, the profile weight write) reaches the server
/// exactly once, through the app's real services and sync engine.

const _user = '11111111-1111-4111-8111-111111111111';

ActivitySession _run(String id) {
  final start = DateTime.now().subtract(const Duration(hours: 2));
  return ActivitySession(
    id: id,
    activityType: ActivityType.run,
    startTime: start,
    endTime: start.add(const Duration(minutes: 30)),
    totalDistanceMeters: 5000,
    totalDurationSeconds: 1800,
    avgPaceSecondsPerKm: 360,
    calories: 350,
    steps: 5600,
    stepCountReliable: true,
    points: [
      for (var i = 0; i < 3; i++)
        TrackPoint(
          latitude: 12.97 + i * 0.0001,
          longitude: 77.59,
          timestamp: start.add(Duration(seconds: i)),
          accuracy: 4,
          speed: 2.8,
          altitude: 900,
        ),
    ],
  );
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = await initIsarForTests();
  final isarReady = skip == null;

  late FakeBackend backend;
  late TestDevice phone;

  setUp(() async {
    if (!isarReady) return;
    backend = FakeBackend();
    phone = await TestDevice.create(backend, online: false);
    await phone.signIn(_user);
  });

  tearDown(() async {
    if (isarReady) await phone.dispose();
  });

  test('entries logged offline upload once when the network returns', () async {
    await phone.water.addWaterLog(_user, 250);
    await phone.water.addWaterLog(_user, 300);
    expect(await phone.weight.add(72.5), isNull);
    await phone.activity.saveSession(_run('run-1'));
    await eventually(() => phone.writes.countFor(_user) == 1);

    // Nothing is attempted without a network.
    await phone.sync.sync(force: true);
    expect(backend.requests, isEmpty);
    // The profile weight write waits in the outbox; logs wait in Isar.
    expect(phone.writes.countFor(_user), 1);
    expect(await phone.sync.pendingCount(), 2 + 1 + 1 + 1);

    // The app is killed and reopened while still offline: the outbox
    // and the unsynced rows are still there.
    final reopened = PendingWrites(phone.prefs, phone.connectivity);
    expect(reopened.countFor(_user), 1);

    // Network back: the sync engine runs on its own (reconnect event).
    phone.sync.start();
    await phone.network.set(true);
    await eventually(() => backend.live('activity_sessions').isNotEmpty);
    await phone.settle();

    expect(backend.live('water_logs').map((r) => r['amount_ml']), [250, 300]);
    expect(backend.live('weight_logs').single['weight_kg'], 72.5);
    expect(backend.live('activity_sessions').single['id'], 'run-1');
    expect(backend.count('PATCH user_health_data'), 1);
    expect(phone.writes.countFor(_user), 0);
    expect(await phone.sync.pendingCount(), 0);

    // A second sync (and a forced pull) sends nothing again and pulling
    // our own rows back doesn't duplicate them locally.
    final posts = backend.requests.where((r) => r.startsWith('POST')).length;
    await phone.sync.sync(force: true);
    expect(backend.requests.where((r) => r.startsWith('POST')).length, posts);
    expect(await phone.water.getTodayLogs(_user), hasLength(2));
    expect(await phone.activity.getSessions(), hasLength(1));
    expect(backend.rows('water_logs'), hasLength(2));
  }, skip: skip);

  test('a row the server refuses does not hold back the others', () async {
    // Logged by an old version before the app checked ranges.
    await phone.isar.writeTxn(
      () => phone.isar.waterLogCaches.put(
        WaterLogCache()
          ..userId = _user
          ..amountMl = 9000
          ..timestamp = DateTime.now().subtract(const Duration(days: 3))
          ..isSynced = false,
      ),
    );
    await phone.water.addWaterLog(_user, 250);
    expect(await phone.weight.add(70), isNull);
    await eventually(() => phone.writes.countFor(_user) == 1);
    backend.reject = (table, row) =>
        table == 'water_logs' && (row['amount_ml'] as int) > 5000
        ? '23514'
        : null;

    await phone.network.set(true);
    await phone.sync.sync(force: true);

    expect(backend.live('water_logs').map((r) => r['amount_ml']), [250]);
    expect(backend.live('weight_logs'), hasLength(1));
    // Kept on the phone, not offered again.
    final local = await phone.isar.waterLogCaches.where().findAll();
    expect(local.map((l) => l.amountMl), containsAll([9000, 250]));
    expect(await phone.sync.pendingCount(), 0);

    final before = backend.count('POST water_logs');
    await phone.sync.sync(force: true);
    expect(backend.count('POST water_logs'), before);
  }, skip: skip);

  test(
    'an expired session keeps queued writes until it is refreshed',
    () async {
      expect(await phone.weight.add(71), isNull);
      await eventually(() => phone.writes.countFor(_user) == 1);

      backend.failTable['user_health_data'] = 'PGRST303';
      await phone.network.set(true);
      for (var i = 0; i < 6; i++) {
        await phone.sync.sync(force: true);
      }
      // More runs than the 5 attempts a rejected write gets: still queued,
      // and the logs themselves uploaded meanwhile.
      expect(phone.writes.countFor(_user), 1);
      expect(backend.live('weight_logs'), hasLength(1));

      backend.failTable.clear();
      await phone.sync.sync(force: true);
      expect(phone.writes.countFor(_user), 0);
      expect(backend.count('PATCH user_health_data'), 7);
    },
    skip: skip,
  );
}
