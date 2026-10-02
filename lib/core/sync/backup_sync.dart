import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';

/// One kind of small per-user data backed up as a single JSON document
/// (a `user_backups` row, see migration 20261011_user_backups.sql).
abstract class BackupSource {
  /// Row kind, `[a-z_]`, stable across app versions.
  String get kind;

  /// The current local data, JSON-encodable.
  Future<Object?> export(String userId);

  /// Replaces the local data with [data] from the backup.
  Future<void> restore(String userId, Object? data);
}

/// Backs up a fixed set of SharedPreferences keys as they are.
///
/// Keys may contain `{user}`, replaced by the user id (per-user keys such as
/// Vita's check-ins). The backup stores the template, so it restores onto
/// any device and account id.
class PrefsBackupSource implements BackupSource {
  @override
  final String kind;
  final SharedPreferences _prefs;
  final List<String> keys;

  /// Runs after a restore, e.g. to reschedule reminders.
  final Future<void> Function()? onRestored;

  PrefsBackupSource(this.kind, this._prefs, this.keys, {this.onRestored});

  String _key(String template, String userId) =>
      template.replaceAll('{user}', userId);

  @override
  Future<Object?> export(String userId) async => {
    for (final k in keys) k: _prefs.get(_key(k, userId)),
  };

  @override
  Future<void> restore(String userId, Object? data) async {
    if (data is! Map) return;
    for (final template in keys) {
      final key = _key(template, userId);
      final value = data[template];
      switch (value) {
        case null:
          await _prefs.remove(key);
        case String v:
          await _prefs.setString(key, v);
        case bool v:
          await _prefs.setBool(key, v);
        case int v:
          await _prefs.setInt(key, v);
        case double v:
          await _prefs.setDouble(key, v);
        case List v:
          await _prefs.setStringList(key, [for (final e in v) '$e']);
        default:
          debugPrint('Backup "$kind": unexpected value for $template');
      }
    }
    await onRestored?.call();
  }
}

/// Syncs [BackupSource]s with `user_backups`, last writer wins.
///
/// Sources don't report edits: on every sync each source is exported and
/// compared with the copy last known to match the server. A difference is a
/// local edit, uploaded with the time it was first noticed. The server
/// ignores uploads that aren't newer than its row, so a fresh install
/// (whose untouched data is uploaded with an epoch time) never overwrites
/// an existing backup and instead receives it on the following pull.
class BackupSyncAdapter implements SyncAdapter {
  final SharedPreferences _prefs;
  final List<BackupSource> _sources;

  BackupSyncAdapter(this._prefs, this._sources);

  @override
  String get table => 'user_backups';

  static final _epoch = DateTime.utc(1970);

  /// Uploads in flight: kind -> canonical data sent.
  final Map<String, String> _sending = {};

  String _stateKey(String userId, String kind) => 'backup_state_${userId}_$kind';

  _BackupState? _state(String userId, String kind) {
    final raw = _prefs.getString(_stateKey(userId, kind));
    if (raw == null) return null;
    try {
      return _BackupState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveState(String userId, String kind, _BackupState state) =>
      _prefs.setString(_stateKey(userId, kind), jsonEncode(state.toJson()));

  @override
  Future<List<PendingRow>> pending(String userId) async {
    final rows = <PendingRow>[];
    for (final source in _sources) {
      final data = await source.export(userId);
      final canonical = canonicalJson(data);
      final state = _state(userId, source.kind);
      if (state?.synced == canonical) continue;

      // Never synced for this account: the data may be untouched defaults,
      // so let any existing backup win (epoch). Otherwise keep the time the
      // edit was first noticed, stable across retries.
      final changedAt = state == null
          ? _epoch
          : (state.pendingSince ?? DateTime.now().toUtc());
      if (state?.pendingSince != changedAt) {
        await _saveState(
          userId,
          source.kind,
          _BackupState(synced: state?.synced, pendingSince: changedAt),
        );
      }
      _sending[source.kind] = canonical;
      rows.add(PendingRow(source.kind, {
        'id': '$userId:${source.kind}',
        'user_id': userId,
        'kind': source.kind,
        'data': data,
        'changed_at': changedAt.toIso8601String(),
      }));
    }
    return rows;
  }

  @override
  Future<void> markSynced(String userId, List<Object> localKeys) async {
    for (final kind in localKeys.cast<String>()) {
      final sent = _sending.remove(kind);
      if (sent == null) continue;
      await _saveState(userId, kind, _BackupState(synced: sent));
    }
  }

  @override
  Future<void> apply(String userId, List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      if (row['deleted_at'] != null) continue;
      final kind = row['kind'] as String?;
      final source = _sources.where((s) => s.kind == kind).firstOrNull;
      if (source == null) continue; // Kind from a newer app version.

      final remote = canonicalJson(row['data']);
      final state = _state(userId, source.kind);
      if (state?.synced == remote) continue; // Our own upload coming back.

      final local = canonicalJson(await source.export(userId));
      final localEdited = state != null && state.synced != local;
      if (localEdited) {
        // Unsent local edit: keep it if it's newer (it uploads next run).
        final remoteAt = DateTime.parse(row['changed_at'] as String);
        final localAt = state.pendingSince ?? DateTime.now().toUtc();
        if (localAt.isAfter(remoteAt)) continue;
      }

      try {
        await source.restore(userId, row['data']);
        await _saveState(
          userId,
          source.kind,
          _BackupState(synced: canonicalJson(await source.export(userId))),
        );
      } catch (e) {
        debugPrint('Backup "${source.kind}" restore failed: $e');
      }
    }
  }
}

/// JSON with map keys sorted at every level, so equal data always encodes
/// the same (Postgres jsonb reorders keys).
String canonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _sorted(value[k])};
  }
  if (value is List) return [for (final v in value) _sorted(v)];
  return value;
}

class _BackupState {
  /// Canonical data last known to match the server.
  final String? synced;

  /// When the current unsent local edit was first noticed.
  final DateTime? pendingSince;

  const _BackupState({this.synced, this.pendingSince});

  Map<String, dynamic> toJson() => {
    'synced': synced,
    'pendingSince': pendingSince?.toIso8601String(),
  };

  factory _BackupState.fromJson(Map<String, dynamic> json) => _BackupState(
    synced: json['synced'] as String?,
    pendingSince: json['pendingSince'] == null
        ? null
        : DateTime.parse(json['pendingSince'] as String),
  );
}
