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

/// A source whose data can be merged with a copy edited on another device,
/// so an unsent local edit and the other device's edit both survive.
abstract interface class MergeableBackupSource implements BackupSource {
  /// Three-way merge of exported data: [base] is the copy both sides last
  /// agreed on (null if unknown). Where only one side changed something,
  /// that side wins; where both did, [local] wins (it uploads next).
  Object? merge({
    required Object? base,
    required Object? local,
    required Object? remote,
  });
}

/// Backs up a fixed set of SharedPreferences keys as they are.
///
/// Keys may contain `{user}`, replaced by the user id (per-user keys such as
/// Vita's check-ins). The backup stores the template, so it restores onto
/// any device and account id.
class PrefsBackupSource implements MergeableBackupSource {
  @override
  final String kind;
  final SharedPreferences _prefs;
  final List<String> keys;

  /// Keys holding JSON collections that grow on each device (check-ins,
  /// daily scores, workout notes): merged entry by entry instead of as one
  /// value. A null id function means a JSON object whose keys are the ids;
  /// otherwise a JSON list whose entries the function identifies.
  final Map<String, String? Function(Object? entry)?> entryKeys;

  /// Runs after a restore, e.g. to reschedule reminders.
  final Future<void> Function()? onRestored;

  PrefsBackupSource(
    this.kind,
    this._prefs,
    this.keys, {
    this.onRestored,
    this.entryKeys = const {},
  });

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

  @override
  Object? merge({
    required Object? base,
    required Object? local,
    required Object? remote,
  }) {
    final b = _asMap(base), l = _asMap(local), r = _asMap(remote);
    return {
      for (final key in keys)
        key: entryKeys.containsKey(key)
            ? _mergeEntries(entryKeys[key], b[key], l[key], r[key])
            : _pick(b[key], l[key], r[key]),
    };
  }

  static Map<String, Object?> _asMap(Object? value) => value is Map
      ? {for (final e in value.entries) '${e.key}': e.value}
      : const {};

  /// One value, three-way: the side that changed it wins, local on a tie.
  static Object? _pick(Object? base, Object? local, Object? remote) {
    if (canonicalJson(local) == canonicalJson(base)) return remote;
    return local;
  }

  /// [base], [local] and [remote] are JSON strings of one collection.
  static Object? _mergeEntries(
    String? Function(Object? entry)? idOf,
    Object? base,
    Object? local,
    Object? remote,
  ) {
    final b = _entries(idOf, base);
    final l = _entries(idOf, local);
    final r = _entries(idOf, remote);
    // Not a readable collection on one side: fall back to the whole value.
    if (l == null || r == null) return _pick(base, local, remote);
    final ids = {...l.keys, ...r.keys}.toList()..sort();
    final merged = <String, Object?>{};
    for (final id in ids) {
      final value = _pick(b?[id], l[id], r[id]);
      if (value != null) merged[id] = value;
    }
    if (merged.isEmpty && local == null && remote == null) return null;
    return jsonEncode(idOf == null ? merged : merged.values.toList());
  }

  /// Entries by id: empty for a missing value, null when unreadable.
  static Map<String, Object?>? _entries(
    String? Function(Object? entry)? idOf,
    Object? raw,
  ) {
    if (raw == null) return {};
    if (raw is! String) return null;
    try {
      final decoded = jsonDecode(raw);
      if (idOf == null) return decoded is Map ? _asMap(decoded) : null;
      if (decoded is! List) return null;
      final out = <String, Object?>{};
      for (final entry in decoded) {
        final id = idOf(entry);
        if (id == null) return null;
        out[id] = entry;
      }
      return out;
    } catch (_) {
      return null;
    }
  }
}

/// Id of a stored Vita check-in (`{"d": "2026-10-18T08:30:00", ...}`): its
/// day, since a day holds one check-in. Null when unreadable.
String? checkInDayId(Object? entry) {
  final d = entry is Map ? entry['d'] : null;
  return d is String && d.length >= 10 ? d.substring(0, 10) : null;
}

/// Adapters whose rows are pulled before local changes are pushed, so an
/// upload is merged with other devices' edits instead of replacing them.
abstract interface class PullBeforePush {
  /// Records when local edits were made, even with no network, so an
  /// offline edit keeps its real time.
  Future<void> noteEdits(String userId);
}

/// Syncs [BackupSource]s with `user_backups`, last writer wins.
///
/// Sources don't report edits: on every sync each source is exported and
/// compared with the copy last known to match the server. A difference is a
/// local edit, uploaded with the time it was first noticed. The server
/// ignores uploads that aren't newer than its row, so a fresh install
/// (whose untouched data is uploaded with an epoch time) never overwrites
/// an existing backup and instead receives it on the following pull.
class BackupSyncAdapter implements SyncAdapter, PullBeforePush {
  final SharedPreferences _prefs;
  final List<BackupSource> _sources;

  BackupSyncAdapter(this._prefs, this._sources);

  @override
  String get table => 'user_backups';

  static final _epoch = DateTime.utc(1970);

  /// Uploads in flight: kind -> canonical data sent.
  final Map<String, String> _sending = {};

  String _stateKey(String userId, String kind) =>
      'backup_state_${userId}_$kind';

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
  Future<void> noteEdits(String userId) async {
    for (final source in _sources) {
      try {
        final canonical = canonicalJson(await source.export(userId));
        final state = _state(userId, source.kind);
        if (state == null || state.synced == canonical) continue;
        if (state.pendingSince != null) continue;
        await _saveState(
          userId,
          source.kind,
          _BackupState(
            synced: state.synced,
            pendingSince: DateTime.now().toUtc(),
          ),
        );
      } catch (e) {
        debugPrint('Backup "${source.kind}" edit check failed: $e');
      }
    }
  }

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
      rows.add(
        PendingRow(source.kind, {
          'id': '$userId:${source.kind}',
          'user_id': userId,
          'kind': source.kind,
          'data': data,
          'changed_at': changedAt.toIso8601String(),
        }),
      );
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

      final localData = await source.export(userId);
      final local = canonicalJson(localData);
      final localEdited = state != null && state.synced != local;
      final remoteAt = DateTime.parse(row['changed_at'] as String);
      if (localEdited && source is MergeableBackupSource) {
        // Unsent local edit and an edit from another device: keep both.
        try {
          await _merge(userId, source, state, localData, row['data'], remoteAt);
        } catch (e) {
          debugPrint('Backup "${source.kind}" merge failed: $e');
        }
        continue;
      }
      if (localEdited) {
        // Unsent local edit: keep it if it's newer (it uploads next run).
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

extension on BackupSyncAdapter {
  /// Restores the merge of [local] and [remote] and leaves it pending, so
  /// the next push uploads it.
  Future<void> _merge(
    String userId,
    MergeableBackupSource source,
    _BackupState state,
    Object? local,
    Object? remote,
    DateTime remoteAt,
  ) async {
    final base = state.synced == null ? null : jsonDecode(state.synced!);
    final merged = source.merge(base: base, local: local, remote: remote);
    if (canonicalJson(merged) != canonicalJson(local)) {
      await source.restore(userId, merged);
    }
    final remoteCanonical = canonicalJson(remote);
    final settled = canonicalJson(await source.export(userId));
    final now = DateTime.now().toUtc();
    // Must upload as newer than the row it includes, even if this phone's
    // clock is behind the other's.
    final uploadAt = now.isAfter(remoteAt)
        ? now
        : remoteAt.add(const Duration(milliseconds: 1));
    await _saveState(
      userId,
      source.kind,
      _BackupState(
        synced: remoteCanonical,
        pendingSince: settled == remoteCanonical ? null : uploadAt,
      ),
    );
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
