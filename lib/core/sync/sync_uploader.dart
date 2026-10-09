import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';

/// The one server call the uploader makes, so tests can swap in a fake.
abstract interface class SyncRemote {
  /// Inserts or updates [rows] (a single row map or a list of them) in
  /// [table], matching on `id`.
  Future<void> upsert(String table, Object rows);
}

/// [SyncRemote] backed by Supabase (PostgREST).
class SupabaseSyncRemote implements SyncRemote {
  final SupabaseClient _client;

  const SupabaseSyncRemote(this._client);

  @override
  Future<void> upsert(String table, Object rows) =>
      _client.from(table).upsert(rows, onConflict: 'id');
}

/// Runs one sync request with a timeout, retrying transient network
/// failures with a short exponential backoff (300 ms, 600 ms...). Any other
/// error is rethrown at once.
Future<T> retrySyncRequest<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration timeout = const Duration(seconds: 30),
  Duration baseDelay = const Duration(milliseconds: 300),
}) async {
  var attempts = 0;
  while (true) {
    attempts++;
    try {
      return await action().timeout(timeout);
    } catch (e) {
      if (attempts >= maxAttempts || !isOfflineError(e)) rethrow;
      await Future<void>.delayed(baseDelay * pow(2, attempts - 1).toInt());
    }
  }
}

/// Uploads one adapter's pending rows in batches.
///
/// When the server refuses the data itself (check constraint, value too
/// long, out of range, missing value) the batch is resent row by row: the
/// good rows still upload and the refused ones stay on this device only.
/// Every row of the batch is then marked synced, so a refused row isn't
/// retried on every sync (it uploads again only if it's edited) and can't
/// block the rest of the table. Any other failure (network, timeout, server
/// error) is rethrown with nothing marked, so the whole batch retries later.
class SyncUploader {
  final SyncRemote _remote;
  final int batchSize;
  final Duration requestTimeout;
  final Duration retryDelay;

  const SyncUploader(
    this._remote, {
    this.batchSize = 100,
    this.requestTimeout = const Duration(seconds: 30),
    this.retryDelay = const Duration(milliseconds: 300),
  });

  /// Postgres refused the data itself, so retrying the same row can never
  /// succeed.
  static bool isRejectedRow(Object e) =>
      e is PostgrestException &&
      const {'23514', '22001', '22003', '23502'}.contains(e.code);

  Future<void> push(SyncAdapter adapter, String userId) async {
    final pending = await adapter.pending(userId);
    for (var i = 0; i < pending.length; i += batchSize) {
      final batch = pending.skip(i).take(batchSize).toList();
      try {
        await _send(adapter.table, [for (final p in batch) p.row]);
      } catch (e) {
        if (!isRejectedRow(e)) rethrow;
        // A row breaks a server limit (e.g. logged before the app checked
        // ranges): send the batch row by row so one bad entry can't block
        // the whole table forever.
        await _pushOneByOne(adapter, batch);
      }
      await adapter.markSynced(userId, [for (final p in batch) p.localKey]);
    }
  }

  Future<void> _pushOneByOne(SyncAdapter adapter, List<PendingRow> batch) async {
    for (final p in batch) {
      try {
        await _send(adapter.table, p.row);
      } catch (e, stack) {
        if (!isRejectedRow(e)) rethrow;
        // Kept on this device, just not backed up.
        CrashReporter.report(
          e,
          stack,
          reason: 'Sync of ${adapter.table} row rejected by server limits',
        );
      }
    }
  }

  Future<void> _send(String table, Object rows) => retrySyncRequest(
    () => _remote.upsert(table, rows),
    timeout: requestTimeout,
    baseDelay: retryDelay,
  );
}
