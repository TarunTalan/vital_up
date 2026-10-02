import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';

class _Hooks implements SyncHooks {
  int scheduled = 0;

  @override
  void schedule() => scheduled++;

  @override
  Future<void> recordDelete(String table, String id) async {}
}

void main() {
  group('isOfflineError', () {
    test('network failures are offline, server answers are not', () {
      expect(isOfflineError(const SocketException('Failed host lookup')), isTrue);
      expect(isOfflineError(Exception('ClientException: Connection reset')), isTrue);
      expect(isOfflineError(Exception('duplicate key value')), isFalse);
      expect(isOfflineError(StateError('bad state')), isFalse);
    });
  });

  group('CacheStore', () {
    late Directory dir;
    late CacheStore cache;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('cache_test');
      cache = CacheStore(ConnectivityService(), directory: dir);
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('a fresh value is served without a request', () async {
      var calls = 0;
      Future<int> remote() async => ++calls;

      expect(await cache.fetch('k', remote: remote, maxAge: const Duration(minutes: 5)), 1);
      expect(await cache.fetch('k', remote: remote, maxAge: const Duration(minutes: 5)), 1);
      expect(calls, 1);
    });

    test('a stale value is refetched; forceRefresh always fetches', () async {
      var calls = 0;
      Future<int> remote() async => ++calls;

      await cache.fetch('k', remote: remote, maxAge: Duration.zero);
      expect(await cache.fetch('k', remote: remote, maxAge: Duration.zero), 2);
      expect(
        await cache.fetch(
          'k',
          remote: remote,
          maxAge: const Duration(days: 1),
          forceRefresh: true,
        ),
        3,
      );
    });

    test('concurrent fetches of one key share a request', () async {
      var calls = 0;
      Future<int> remote() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return calls;
      }

      final results = await Future.wait([
        for (var i = 0; i < 5; i++)
          cache.fetch('k', remote: remote, maxAge: const Duration(minutes: 1)),
      ]);
      expect(calls, 1);
      expect(results, everyElement(1));
    });

    test('offline: the stale copy is returned instead of the error', () async {
      await cache.fetch('k', remote: () async => 'saved', maxAge: Duration.zero);
      final value = await cache.fetch<String>(
        'k',
        remote: () async => throw const SocketException('offline'),
        maxAge: Duration.zero,
      );
      expect(value, 'saved');
    });

    test('offline with nothing cached rethrows; server errors always rethrow', () async {
      expect(
        cache.fetch<String>(
          'none',
          remote: () async => throw const SocketException('offline'),
          maxAge: Duration.zero,
        ),
        throwsA(isA<SocketException>()),
      );
      await cache.fetch('k', remote: () async => 'saved', maxAge: Duration.zero);
      expect(
        cache.fetch<String>(
          'k',
          remote: () async => throw StateError('rejected'),
          maxAge: Duration.zero,
        ),
        throwsStateError,
      );
    });

    test('values survive a restart and decode through the codec', () async {
      await cache.fetch<List<DateTime>>(
        'dates',
        remote: () async => [DateTime.utc(2026, 10, 2)],
        maxAge: const Duration(hours: 1),
        encode: (v) => [for (final d in v) d.toIso8601String()],
        decode: (j) => [for (final s in j as List) DateTime.parse(s as String)],
      );

      final restarted = CacheStore(ConnectivityService(), directory: dir);
      final cached = await restarted.read<List<DateTime>>(
        'dates',
        decode: (j) => [for (final s in j as List) DateTime.parse(s as String)],
      );
      expect(cached?.value, [DateTime.utc(2026, 10, 2)]);
    });

    test('removeWhere drops keys by prefix only', () async {
      await cache.write('user:a:x', 1);
      await cache.write('user:a:y', 2);
      await cache.write('user:b:x', 3);
      await cache.removeWhere('user:a:');

      final restarted = CacheStore(ConnectivityService(), directory: dir);
      expect(await restarted.read<int>('user:a:x'), isNull);
      expect(await restarted.read<int>('user:a:y'), isNull);
      expect((await restarted.read<int>('user:b:x'))?.value, 3);
    });
  });

  group('PendingWrites', () {
    late PendingWrites writes;
    late _Hooks hooks;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      writes = PendingWrites(
        await SharedPreferences.getInstance(),
        ConnectivityService(),
      );
      hooks = _Hooks();
      writes.attach(hooks);
    });

    test('updates to the same row coalesce, later fields win', () async {
      await writes.enqueue(PendingWrite.update(
        'profiles',
        values: {'name': 'A', 'city': 'Pune'},
        match: {'id': 'u1'},
        userId: 'u1',
      ));
      await writes.enqueue(PendingWrite.update(
        'profiles',
        values: {'name': 'B'},
        match: {'id': 'u1'},
        userId: 'u1',
      ));

      expect(writes.countFor('u1'), 1);
      expect(hooks.scheduled, 2);
    });

    test('writes are kept per user', () async {
      await writes.enqueue(PendingWrite.rpc('set_my_timezone', params: {'tz': 'UTC'}, userId: 'u1'));
      await writes.enqueue(PendingWrite.rpc('set_my_timezone', params: {'tz': 'UTC'}, userId: 'u2'));

      expect(writes.countFor('u1'), 1);
      expect(writes.countFor('u2'), 1);
    });

    test('queued writes survive a restart', () async {
      await writes.enqueue(PendingWrite.upsert(
        'user_health_data',
        values: {'id': 'u1', 'weight_kg': 70.5},
        userId: 'u1',
      ));

      final reopened = PendingWrites(
        await SharedPreferences.getInstance(),
        ConnectivityService(),
      );
      expect(reopened.countFor('u1'), 1);
    });
  });
}
