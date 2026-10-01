import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';

/// Backs up the logs recorded on this device to Supabase and brings back
/// entries made on other devices (see migration 20261008_synced_logs.sql).
///
/// Offline first: everything is written locally, then uploaded when
/// possible. Includes exponential backoff retry scheduling for intermittent
/// network drops when users are jogging or in low-connectivity areas.
class SyncService with WidgetsBindingObserver implements SyncHooks {
  final SupabaseClient _client;
  final SharedPreferences _prefs;
  final List<SyncAdapter> _adapters;

  SyncService(this._client, this._prefs, this._adapters);

  static const _keyDeletes = 'sync_pending_deletes';
  static const _pageSize = 500;
  static const _uploadBatch = 100;

  /// Pull a little before the last cursor, in case rows committed out of
  /// order. Merging is idempotent, so re-reading them is harmless.
  static const _pullOverlap = Duration(minutes: 2);

  Future<void>? _running;
  Timer? _debounce;
  Timer? _retryTimer;
  DateTime? _lastForegroundSync;
  StreamSubscription<AuthState>? _authSub;
  int _consecutiveFailures = 0;
  final Random _random = Random();

  String? get _userId => _client.auth.currentUser?.id;

  /// Starts syncing on sign-in and app resume. Call once at startup.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _authSub = _client.auth.onAuthStateChange.listen((auth) {
      if (auth.session != null &&
          (auth.event == AuthChangeEvent.initialSession ||
              auth.event == AuthChangeEvent.signedIn)) {
        _consecutiveFailures = 0;
        sync();
      }
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _debounce?.cancel();
    _retryTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastForegroundSync;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastForegroundSync = DateTime.now();
    // Reset failure backoff on app foregrounding so we attempt fresh sync immediately
    _consecutiveFailures = 0;
    _retryTimer?.cancel();
    sync();
  }

  /// Call after a local change; batches bursts of edits into one sync.
  @override
  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), sync);
  }

  /// Remembers a deleted entry so other devices drop it too.
  @override
  Future<void> recordDelete(String table, String id) async {
    final userId = _userId;
    if (userId == null) return;
    await _prefs.setStringList(_keyDeletes, [
      ...?_prefs.getStringList(_keyDeletes),
      jsonEncode({'table': table, 'id': id, 'user': userId}),
    ]);
    schedule();
  }

  /// Uploads and downloads everything. Safe to call often: concurrent
  /// calls share one run. Never throws.
  Future<void> sync() =>
      _running ??= _run().whenComplete(() => _running = null);

  /// Entries recorded here but not backed up yet.
  Future<int> pendingCount() async {
    final userId = _userId;
    if (userId == null) return 0;
    var count = (_prefs.getStringList(_keyDeletes) ?? const []).length;
    for (final adapter in _adapters) {
      try {
        count += (await adapter.pending(userId)).length;
      } catch (_) {}
    }
    return count;
  }

  /// Forgets what was downloaded, so the next sync pulls everything again.
  /// Call when local data is wiped (sign-out).
  Future<void> reset() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith('sync_cursor_')) await _prefs.remove(key);
    }
    await _prefs.remove(_keyDeletes);
  }

  Future<void> _run() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _pushDeletes(userId);
      for (final adapter in _adapters) {
        await _push(adapter, userId);
        await _pull(adapter, userId);
      }
      // On full success, reset exponential backoff counter and cancel retries
      _consecutiveFailures = 0;
      _retryTimer?.cancel();
    } catch (e, stack) {
      if (_looksOffline(e)) {
        _scheduleExponentialBackoffRetry();
        return;
      }
      CrashReporter.report(e, stack, reason: 'Sync failed');
      _scheduleExponentialBackoffRetry();
    }
  }

  /// Schedules an automatic retry with exponential backoff and jitter
  /// for intermittent drops during workouts / jogging.
  void _scheduleExponentialBackoffRetry() {
    _consecutiveFailures++;
    _retryTimer?.cancel();

    // Exponential delays: 2s, 4s, 8s, 16s, 32s, capped at 60s
    final baseSeconds = min(60, 2 * pow(2, min(_consecutiveFailures - 1, 5)).toInt());
    // Jitter: +/- 25%
    final jitterFactor = 0.75 + (_random.nextDouble() * 0.50);
    final delayMs = (baseSeconds * 1000 * jitterFactor).round();

    debugPrint(
      '[SyncService] Sync dropped or offline (failure #$_consecutiveFailures). Retrying in ${delayMs}ms...',
    );

    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_userId != null) {
        sync();
      }
    });
  }

  Future<void> _push(SyncAdapter adapter, String userId) async {
    final pending = await adapter.pending(userId);
    for (var i = 0; i < pending.length; i += _uploadBatch) {
      final batch = pending.skip(i).take(_uploadBatch).toList();
      await _retryOperation(() async {
        await _client.from(adapter.table).upsert([
          for (final p in batch) p.row,
        ], onConflict: 'id');
      });
      await adapter.markSynced(userId, [for (final p in batch) p.localKey]);
    }
  }

  Future<void> _pull(SyncAdapter adapter, String userId) async {
    final cursorKey = 'sync_cursor_${adapter.table}_$userId';
    final saved = _prefs.getString(cursorKey);
    var cursor = saved == null
        ? null
        : DateTime.parse(
            saved,
          ).subtract(_pullOverlap).toUtc().toIso8601String();

    while (true) {
      var query = _client.from(adapter.table).select().eq('user_id', userId);
      if (cursor != null) query = query.gt('updated_at', cursor);

      final rows = await _retryOperation<List<Map<String, dynamic>>>(() async {
        final res = await query.order('updated_at').limit(_pageSize);
        return List<Map<String, dynamic>>.from(res);
      });

      if (rows.isEmpty) break;
      await adapter.apply(userId, rows);
      cursor = rows.last['updated_at'] as String;
      await _prefs.setString(cursorKey, cursor);
      if (rows.length < _pageSize) break;
    }
  }

  Future<void> _pushDeletes(String userId) async {
    final queued = _prefs.getStringList(_keyDeletes) ?? const [];
    if (queued.isEmpty) return;
    final remaining = <String>[];
    for (var i = 0; i < queued.length; i++) {
      final d = jsonDecode(queued[i]) as Map<String, dynamic>;
      // Another account's leftovers can't be sent from this session.
      if (d['user'] != userId) continue;
      try {
        await _retryOperation(() async {
          await _client
              .from(d['table'] as String)
              .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', d['id'] as String);
        });
      } catch (e) {
        if (_looksOffline(e)) {
          remaining.addAll(queued.skip(i));
          break;
        }
        remaining.add(queued[i]);
      }
    }
    await _prefs.setStringList(_keyDeletes, remaining);
  }

  /// Transient operation retry with rapid exponential backoff (e.g., 500ms, 1s)
  Future<T> _retryOperation<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await action();
      } catch (e) {
        if (attempts >= maxAttempts || !_looksOffline(e)) {
          rethrow;
        }
        final delayMs = (300 * pow(2, attempts - 1)).toInt();
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  static bool _looksOffline(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection') ||
        text.contains('timeout') ||
        text.contains('handshake') ||
        text.contains('network is unreachable');
  }
}
