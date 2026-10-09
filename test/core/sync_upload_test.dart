import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';
import 'package:vital_up/core/sync/sync_uploader.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

/// Server stand-in: stores upserted rows by id, refuses rows whose id is in
/// [rejected] (like a Postgres CHECK / length violation, which fails the
/// whole request), and can fail every call with [failWith].
class _FakeRemote implements SyncRemote {
  final Map<String, String> rejected;
  Object? failWith;
  final stored = <String, Map<String, dynamic>>{};
  final calls = <List<String>>[];

  _FakeRemote({this.rejected = const {}});

  @override
  Future<void> upsert(String table, Object rows) async {
    final list = rows is List
        ? rows.cast<Map<String, dynamic>>()
        : [rows as Map<String, dynamic>];
    calls.add([for (final r in list) r['id'] as String]);
    if (failWith != null) throw failWith!;
    for (final r in list) {
      final code = rejected[r['id']];
      if (code != null) {
        throw PostgrestException(message: 'refused', code: code);
      }
    }
    for (final r in list) {
      stored[r['id'] as String] = r;
    }
  }
}

/// Local store stand-in: rows stay until deleted; markSynced only flips a
/// flag, like the real adapters.
class _FakeAdapter implements SyncAdapter {
  final rows = <String, Map<String, dynamic>>{};
  final synced = <String>{};
  final markCalls = <List<Object>>[];

  _FakeAdapter(Iterable<String> ids) {
    for (final id in ids) {
      rows[id] = {'id': id, 'user_id': 'u', 'value': id.length};
    }
  }

  /// A local edit: uploads again.
  void edit(String id) => synced.remove(id);

  @override
  String get table => 'water_logs';

  @override
  Future<List<PendingRow>> pending(String userId) async => [
    for (final e in rows.entries)
      if (!synced.contains(e.key)) PendingRow(e.key, e.value),
  ];

  @override
  Future<void> markSynced(String userId, List<Object> localKeys) async {
    markCalls.add(localKeys);
    synced.addAll(localKeys.cast<String>());
  }

  @override
  Future<void> apply(String userId, List<Map<String, dynamic>> rows) async {}
}

SyncUploader _uploader(SyncRemote remote, {int batchSize = 100}) =>
    SyncUploader(
      remote,
      batchSize: batchSize,
      retryDelay: const Duration(milliseconds: 1),
    );

void main() {
  group('rows refused by the server', () {
    test('one bad row: the rest upload, the bad one stays local', () async {
      final remote = _FakeRemote(rejected: {'b': '23514'});
      final adapter = _FakeAdapter(['a', 'b', 'c']);

      await _uploader(remote).push(adapter, 'u');

      expect(remote.stored.keys, unorderedEquals(['a', 'c']));
      // Batch first, then row by row.
      expect(remote.calls, [
        ['a', 'b', 'c'],
        ['a'],
        ['b'],
        ['c'],
      ]);
      // Every row is marked, so the refused one isn't retried forever.
      expect(adapter.synced, {'a', 'b', 'c'});
      expect(await adapter.pending('u'), isEmpty);
      // Still on the device.
      expect(adapter.rows.keys, containsAll(['a', 'b', 'c']));
    });

    test('a refused row is not sent again on the next sync', () async {
      final remote = _FakeRemote(rejected: {'b': '22001'});
      final adapter = _FakeAdapter(['a', 'b']);
      final uploader = _uploader(remote);

      await uploader.push(adapter, 'u');
      remote.calls.clear();
      await uploader.push(adapter, 'u');

      expect(remote.calls, isEmpty);
      expect(adapter.rows, contains('b'));
    });

    test('a refused row uploads again once it is edited', () async {
      final remote = _FakeRemote(rejected: {'b': '23514'});
      final adapter = _FakeAdapter(['a', 'b']);
      final uploader = _uploader(remote);
      await uploader.push(adapter, 'u');

      // Fixed locally (e.g. corrected value) and saved again.
      remote.rejected.remove('b');
      adapter.edit('b');
      remote.calls.clear();
      await uploader.push(adapter, 'u');

      expect(remote.calls, [
        ['b'],
      ]);
      expect(remote.stored, contains('b'));
    });

    test('every row bad: nothing uploads, all kept and marked', () async {
      final remote = _FakeRemote(
        rejected: {'a': '23514', 'b': '22001', 'c': '22003', 'd': '23502'},
      );
      final adapter = _FakeAdapter(['a', 'b', 'c', 'd']);

      await _uploader(remote).push(adapter, 'u');

      expect(remote.stored, isEmpty);
      expect(adapter.synced, {'a', 'b', 'c', 'd'});
      expect(adapter.rows, hasLength(4));
    });

    test('only the batch with the bad row goes row by row', () async {
      final remote = _FakeRemote(rejected: {'c': '23514'});
      final adapter = _FakeAdapter(['a', 'b', 'c', 'd']);

      await _uploader(remote, batchSize: 2).push(adapter, 'u');

      expect(remote.calls, [
        ['a', 'b'],
        ['c', 'd'],
        ['c'],
        ['d'],
      ]);
      expect(remote.stored.keys, unorderedEquals(['a', 'b', 'd']));
      expect(adapter.markCalls, [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('other database errors are not treated as refused rows', () async {
      // Permission (RLS) and unique violations aren't about the row's values.
      for (final code in ['42501', '23505', 'PGRST000']) {
        final remote = _FakeRemote(rejected: {'b': code});
        final adapter = _FakeAdapter(['a', 'b']);
        await expectLater(
          _uploader(remote).push(adapter, 'u'),
          throwsA(isA<PostgrestException>()),
        );
        expect(adapter.synced, isEmpty, reason: 'code $code');
      }
    });
  });

  group('failures that are not about the data', () {
    test('network error: nothing marked, everything retries later', () async {
      final remote = _FakeRemote()
        ..failWith = const SocketException('Failed host lookup');
      final adapter = _FakeAdapter(['a', 'b']);
      final uploader = _uploader(remote);

      await expectLater(
        uploader.push(adapter, 'u'),
        throwsA(isA<SocketException>()),
      );
      // Retried quickly (3 attempts), never split row by row.
      expect(remote.calls, [
        ['a', 'b'],
        ['a', 'b'],
        ['a', 'b'],
      ]);
      expect(adapter.markCalls, isEmpty);
      expect(await adapter.pending('u'), hasLength(2));

      remote.failWith = null;
      await uploader.push(adapter, 'u');
      expect(remote.stored.keys, unorderedEquals(['a', 'b']));
      expect(adapter.synced, {'a', 'b'});
    });

    test('server error (5xx): nothing marked, retried next sync', () async {
      final remote = _FakeRemote()
        ..failWith = const PostgrestException(
          message: 'Internal Server Error',
          code: '500',
        );
      final adapter = _FakeAdapter(['a']);

      await expectLater(
        _uploader(remote).push(adapter, 'u'),
        throwsA(isA<PostgrestException>()),
      );
      expect(remote.calls, hasLength(1)); // not a transient network error
      expect(adapter.markCalls, isEmpty);
      expect(await adapter.pending('u'), hasLength(1));
    });

    test('timeout: nothing marked', () async {
      final remote = _HangingRemote();
      final adapter = _FakeAdapter(['a']);
      final uploader = SyncUploader(
        remote,
        requestTimeout: const Duration(milliseconds: 20),
        retryDelay: const Duration(milliseconds: 1),
      );

      await expectLater(uploader.push(adapter, 'u'), throwsA(anything));
      expect(remote.calls, 3);
      expect(adapter.markCalls, isEmpty);
    });

    test('network drops while sending row by row: batch not marked', () async {
      final remote = _FlakyAfterRejectRemote();
      final adapter = _FakeAdapter(['a', 'b', 'c']);

      await expectLater(
        _uploader(remote).push(adapter, 'u'),
        throwsA(isA<SocketException>()),
      );
      expect(adapter.markCalls, isEmpty);
      expect(await adapter.pending('u'), hasLength(3));
    });
  });

  group('with the real workout store', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    ActivitySession session(String id) {
      final start = DateTime(2026, 10, 1, 7);
      return ActivitySession(
        id: id,
        activityType: ActivityType.run,
        startTime: start,
        endTime: start.add(const Duration(minutes: 15)),
        totalDistanceMeters: 2500,
        totalDurationSeconds: 900,
        avgPaceSecondsPerKm: 360,
        calories: 180,
        steps: 2800,
        stepCountReliable: true,
        points: const [],
      );
    }

    test('a refused workout is kept on the device, not re-sent', () async {
      final repo = ActivityRepositoryImpl(db);
      await repo.saveSession(session('good'));
      await repo.saveSession(session('bad'));
      final adapter = ActivitySyncAdapter(db);
      final remote = _FakeRemote(rejected: {'bad': '23514'});

      await _uploader(remote).push(adapter, 'u');

      expect(remote.stored.keys, ['good']);
      expect(await adapter.pending('u'), isEmpty);
      final kept = await repo.getSessions();
      expect(kept.map((s) => s.id), unorderedEquals(['good', 'bad']));
    });
  });
}

/// Never answers.
class _HangingRemote implements SyncRemote {
  int calls = 0;

  @override
  Future<void> upsert(String table, Object rows) {
    calls++;
    return Completer<void>().future;
  }
}

/// Batch refused for its data, then the connection drops on the first
/// single-row resend.
class _FlakyAfterRejectRemote implements SyncRemote {
  int calls = 0;

  @override
  Future<void> upsert(String table, Object rows) async {
    calls++;
    if (rows is List) {
      throw const PostgrestException(message: 'refused', code: '23514');
    }
    throw const SocketException('Connection reset');
  }
}
