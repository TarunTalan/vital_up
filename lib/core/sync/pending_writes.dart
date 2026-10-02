import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';

/// One server write waiting for the network.
///
/// Kinds:
/// - `update`: `from(target).update(values).eq(k, v)...` for each [match];
/// - `upsert`: `from(target).upsert(values, onConflict: onConflict)`;
/// - `delete`: `from(target).delete().eq(k, v)...`;
/// - `rpc`:    `rpc(target, params: values)`.
///
/// Writes with the same [key] coalesce: a newer `update`/`upsert` merges its
/// values over the queued one (later fields win), anything else replaces
/// it. So editing a profile five times offline sends one request.
class PendingWrite {
  final String kind;
  final String target;
  final Map<String, dynamic> values;
  final Map<String, Object> match;
  final String? onConflict;
  final String key;
  final String userId;
  final DateTime queuedAt;
  final int attempts;

  const PendingWrite({
    required this.kind,
    required this.target,
    required this.key,
    required this.userId,
    required this.queuedAt,
    this.values = const {},
    this.match = const {},
    this.onConflict,
    this.attempts = 0,
  });

  PendingWrite.update(
    String table, {
    required Map<String, dynamic> values,
    required Map<String, Object> match,
    required String userId,
    String? key,
  }) : this(
         kind: 'update',
         target: table,
         values: values,
         match: match,
         userId: userId,
         key: key ?? 'update:$table:${jsonEncode(match)}',
         queuedAt: DateTime.now(),
       );

  PendingWrite.upsert(
    String table, {
    required Map<String, dynamic> values,
    required String userId,
    String? onConflict,
    String? key,
  }) : this(
         kind: 'upsert',
         target: table,
         values: values,
         onConflict: onConflict,
         userId: userId,
         key: key ?? 'upsert:$table:${values[onConflict ?? 'id'] ?? userId}',
         queuedAt: DateTime.now(),
       );

  PendingWrite.delete(
    String table, {
    required Map<String, Object> match,
    required String userId,
    String? key,
  }) : this(
         kind: 'delete',
         target: table,
         match: match,
         userId: userId,
         key: key ?? 'delete:$table:${jsonEncode(match)}',
         queuedAt: DateTime.now(),
       );

  PendingWrite.rpc(
    String function, {
    Map<String, dynamic> params = const {},
    required String userId,
    String? key,
  }) : this(
         kind: 'rpc',
         target: function,
         values: params,
         userId: userId,
         key: key ?? 'rpc:$function:${jsonEncode(params)}',
         queuedAt: DateTime.now(),
       );

  PendingWrite _copy({Map<String, dynamic>? values, int? attempts}) =>
      PendingWrite(
        kind: kind,
        target: target,
        values: values ?? this.values,
        match: match,
        onConflict: onConflict,
        key: key,
        userId: userId,
        queuedAt: queuedAt,
        attempts: attempts ?? this.attempts,
      );

  Future<void> send(SupabaseClient client) async {
    switch (kind) {
      case 'update':
        var q = client.from(target).update(values);
        for (final e in match.entries) {
          q = q.eq(e.key, e.value);
        }
        await q;
      case 'upsert':
        await client.from(target).upsert(values, onConflict: onConflict);
      case 'delete':
        var q = client.from(target).delete();
        for (final e in match.entries) {
          q = q.eq(e.key, e.value);
        }
        await q;
      case 'rpc':
        await client.rpc(target, params: values);
      default:
        throw StateError('Unknown pending write kind "$kind"');
    }
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'target': target,
    'values': values,
    'match': match,
    'onConflict': onConflict,
    'key': key,
    'user': userId,
    'at': queuedAt.toIso8601String(),
    'attempts': attempts,
  };

  factory PendingWrite.fromJson(Map<String, dynamic> json) => PendingWrite(
    kind: json['kind'] as String,
    target: json['target'] as String,
    values: Map<String, dynamic>.from(json['values'] as Map? ?? const {}),
    match: Map<String, Object>.from(json['match'] as Map? ?? const {}),
    onConflict: json['onConflict'] as String?,
    key: json['key'] as String,
    userId: json['user'] as String,
    queuedAt: DateTime.parse(json['at'] as String),
    attempts: json['attempts'] as int? ?? 0,
  );
}

/// Durable outbox for server writes made while offline. Flushed in order by
/// [SyncService] whenever it runs (reconnect, resume, after local changes).
class PendingWrites {
  final SharedPreferences _prefs;
  final ConnectivityService _connectivity;
  SyncHooks? _hooks;

  PendingWrites(this._prefs, this._connectivity);

  static const _storageKey = 'pending_server_writes_v1';

  /// A write the server keeps rejecting is dropped after this many tries.
  static const _maxAttempts = 5;

  /// Wired by DI once the sync engine exists (it depends on this queue).
  void attach(SyncHooks hooks) => _hooks = hooks;

  List<PendingWrite> _all() => [
    for (final raw in _prefs.getStringList(_storageKey) ?? const <String>[])
      PendingWrite.fromJson(jsonDecode(raw) as Map<String, dynamic>),
  ];

  Future<void> _save(List<PendingWrite> writes) => _prefs.setStringList(
    _storageKey,
    [for (final w in writes) jsonEncode(w.toJson())],
  );

  /// Writes queued for [userId].
  int countFor(String userId) => _all().where((w) => w.userId == userId).length;

  /// Queues [write] (coalescing with a queued one of the same key) and asks
  /// for a sync.
  Future<void> enqueue(PendingWrite write) async {
    final all = _all();
    final i = all.indexWhere(
      (w) => w.key == write.key && w.userId == write.userId,
    );
    if (i == -1) {
      all.add(write);
    } else {
      final old = all[i];
      final merges =
          old.kind == write.kind && (write.kind == 'update' || write.kind == 'upsert');
      // Keep the original position so writes stay in order.
      all[i] = merges
          ? old._copy(values: {...old.values, ...write.values}, attempts: 0)
          : write;
    }
    await _save(all);
    _hooks?.schedule();
  }

  /// Sends [write] now when online; queues it when offline or when the
  /// request fails for lack of network. Other errors are rethrown.
  ///
  /// Returns true if it reached the server.
  Future<bool> sendOrQueue(SupabaseClient client, PendingWrite write) async {
    // An older queued write for the same key must go first, so queue behind it.
    final queuedAhead = _all().any(
      (w) => w.key == write.key && w.userId == write.userId,
    );
    if (!_connectivity.hasNetwork || queuedAhead) {
      await enqueue(write);
      return false;
    }
    try {
      await write.send(client);
      _connectivity.reportSuccess();
      return true;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      _connectivity.reportFailure();
      await enqueue(write);
      return false;
    }
  }

  /// Sends queued writes for [userId] in order. Stops at the first offline
  /// failure (rethrown so the caller can back off); writes the server
  /// rejects are retried a few times, then dropped and reported.
  Future<void> flush(SupabaseClient client, String userId) async {
    final all = _all();
    if (!all.any((w) => w.userId == userId)) return;

    final remaining = <PendingWrite>[];
    Object? offline;
    for (var i = 0; i < all.length; i++) {
      final write = all[i];
      // Another account's writes can't be sent from this session.
      if (offline != null || write.userId != userId) {
        remaining.add(write);
        continue;
      }
      try {
        await write.send(client);
      } catch (e, stack) {
        if (isOfflineError(e)) {
          offline = e;
          remaining.add(write);
          continue;
        }
        if (write.attempts + 1 >= _maxAttempts) {
          CrashReporter.report(
            e,
            stack,
            reason: 'Dropped queued ${write.kind} ${write.target}',
          );
        } else {
          debugPrint('PendingWrites: ${write.key} failed, will retry: $e');
          remaining.add(write._copy(attempts: write.attempts + 1));
        }
      }
    }
    await _save(remaining);
    if (offline != null) throw offline;
  }
}
