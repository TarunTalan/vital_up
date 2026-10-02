import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';
import 'package:vital_up/core/sync/sync_hooks.dart';

/// Backs up the logs recorded on this device to Supabase and brings back
/// entries made on other devices (see migration 20261008_synced_logs.sql),
/// and flushes server writes queued while offline ([PendingWrites]).
///
/// Offline first: everything is written locally, then uploaded when
/// possible.
/// - Local edits trigger an upload only (debounced); downloads happen on
///   sign-in, app resume and reconnect, at most every [_minPullInterval].
/// - With no network interface nothing is attempted; the run happens as
///   soon as [ConnectivityService] reports the network is back.
/// - When the network is up but requests still fail, retries back off
///   exponentially (2 s to 5 min, with jitter).
/// - Each table syncs independently, so one failing table doesn't block
///   the others.
class SyncService with WidgetsBindingObserver implements SyncHooks {
  final SupabaseClient _client;
  final SharedPreferences _prefs;
  final List<SyncAdapter> _adapters;
  final ConnectivityService _connectivity;
  final PendingWrites _writes;

  SyncService(
    this._client,
    this._prefs,
    this._adapters,
    this._connectivity,
    this._writes,
  );

  static const _keyDeletes = 'sync_pending_deletes';
  static const _pageSize = 500;
  static const _uploadBatch = 100;

  /// Pull a little before the last cursor, in case rows committed out of
  /// order. Merging is idempotent, so re-reading them is harmless.
  static const _pullOverlap = Duration(minutes: 2);

  /// Other devices' changes are fetched at most this often (unless forced).
  static const _minPullInterval = Duration(minutes: 5);

  static const _maxBackoff = Duration(minutes: 5);

  Future<void>? _running;
  Future<void>? _queued;
  bool _rerunPull = false;
  Timer? _debounce;
  Timer? _retryTimer;
  DateTime? _lastPull;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<bool>? _onlineSub;
  int _consecutiveFailures = 0;
  final Random _random = Random();

  String? get _userId => _client.auth.currentUser?.id;

  /// Starts syncing on sign-in, app resume and reconnect. Call once at
  /// startup.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _writes.attach(this);
    _authSub = _client.auth.onAuthStateChange.listen((auth) {
      if (auth.session != null &&
          (auth.event == AuthChangeEvent.initialSession ||
              auth.event == AuthChangeEvent.signedIn)) {
        _consecutiveFailures = 0;
        sync(force: true);
      }
    });
    _onlineSub = _connectivity.onlineChanges.listen((online) {
      if (!online) return;
      _consecutiveFailures = 0;
      _retryTimer?.cancel();
      sync();
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _onlineSub?.cancel();
    _debounce?.cancel();
    _retryTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app: upload what changed (settings, goals and other
    // backed-up data don't announce their edits).
    if (state == AppLifecycleState.paused) {
      sync(pull: false);
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    // Fresh attempt on foregrounding; the pull itself is rate-limited.
    _consecutiveFailures = 0;
    _retryTimer?.cancel();
    sync();
  }

  /// Call after a local change; batches bursts of edits into one upload.
  @override
  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), () => sync(pull: false));
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

  /// Uploads local changes and (when due, or with [force]) downloads other
  /// devices' changes. Set [pull] to false to only upload.
  ///
  /// Safe to call often: calls during a run share one follow-up run, and
  /// the returned future completes after it (so "sync, then wipe" on
  /// sign-out really uploads the latest changes). Never throws.
  Future<void> sync({bool pull = true, bool force = false}) {
    final wantsPull = pull &&
        (force ||
            _lastPull == null ||
            DateTime.now().difference(_lastPull!) >= _minPullInterval);
    if (_running != null) {
      _rerunPull |= wantsPull;
      return _queued ??= _running!.then((_) {
        _queued = null;
        final pullAgain = _rerunPull;
        _rerunPull = false;
        return sync(pull: pullAgain, force: pullAgain);
      });
    }
    return _running = _run(pull: wantsPull).whenComplete(() {
      _running = null;
    });
  }

  /// Entries recorded here but not backed up yet.
  Future<int> pendingCount() async {
    final userId = _userId;
    if (userId == null) return 0;
    var count = (_prefs.getStringList(_keyDeletes) ?? const []).length +
        _writes.countFor(userId);
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
    _lastPull = null;
  }

  Future<void> _run({required bool pull}) async {
    final userId = _userId;
    if (userId == null) return;
    // No network at all: wait for the reconnect event instead of retrying.
    if (!_connectivity.hasNetwork) return;

    var failed = false;
    try {
      await _writes.flush(_client, userId);
      await _pushDeletes(userId);
      for (final adapter in _adapters) {
        try {
          await _push(adapter, userId);
          if (pull) await _pull(adapter, userId);
        } catch (e, stack) {
          if (isOfflineError(e)) rethrow;
          failed = true;
          CrashReporter.report(
            e,
            stack,
            reason: 'Sync of ${adapter.table} failed',
          );
        }
      }
      _connectivity.reportSuccess();
      if (pull) _lastPull = DateTime.now();
    } catch (e, stack) {
      failed = true;
      if (isOfflineError(e)) {
        _connectivity.reportFailure();
      } else {
        CrashReporter.report(e, stack, reason: 'Sync failed');
      }
    }

    if (failed) {
      _scheduleRetry();
    } else {
      _consecutiveFailures = 0;
      _retryTimer?.cancel();
    }
  }

  /// Retries with exponential backoff and jitter, for flaky networks
  /// (jogging, tunnels). Skipped when there's no network at all.
  void _scheduleRetry() {
    _consecutiveFailures++;
    _retryTimer?.cancel();
    if (!_connectivity.hasNetwork) return;

    final baseMs = min(
      _maxBackoff.inMilliseconds,
      2000 * pow(2, min(_consecutiveFailures - 1, 8)).toInt(),
    );
    final jitter = 0.75 + _random.nextDouble() * 0.5;
    final delay = Duration(milliseconds: (baseMs * jitter).round());
    debugPrint(
      '[SyncService] Sync failed (#$_consecutiveFailures), '
      'retrying in ${delay.inSeconds}s',
    );
    _retryTimer = Timer(delay, () {
      if (_userId != null) sync();
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
        if (isOfflineError(e)) {
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
        if (attempts >= maxAttempts || !isOfflineError(e)) {
          rethrow;
        }
        final delayMs = (300 * pow(2, attempts - 1)).toInt();
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
  }
}
