import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/network/offline_errors.dart';

/// A cached server response: the decoded value and when it was fetched.
class Cached<T> {
  final T value;
  final DateTime savedAt;

  const Cached(this.value, this.savedAt);

  Duration get age => DateTime.now().difference(savedAt);
}

/// Persistent cache for server reads, so screens open instantly and keep
/// working offline.
///
/// Values are JSON-encodable objects stored one file per key (plus an
/// in-memory copy). Keys should include the user id for personal data, e.g.
/// `'gamification:stats:$userId'`.
///
/// [fetch] is the main entry point:
/// - fresh cached value → returned without a request;
/// - stale or missing → fetched; concurrent fetches of one key share a
///   single request;
/// - fetch fails because the device is offline → the stale copy is
///   returned instead (the error is rethrown only if there is no copy).
class CacheStore {
  final ConnectivityService _connectivity;

  /// [directory] overrides the storage location (tests).
  CacheStore(this._connectivity, {Directory? directory})
    : _override = directory;

  final Directory? _override;
  Directory? _dir;
  final Map<String, Cached<Object?>> _memory = {};
  final Map<String, Future<Object?>> _inFlight = {};

  /// Bumped by [clear]; a fetch that started before a clear (sign-out)
  /// must not write the old account's data back into the cache.
  int _generation = 0;

  /// Longest [fetch] waits for the server before falling back to the
  /// cached copy (or failing with a timeout when there is none).
  static const fetchTimeout = Duration(seconds: 30);

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final dir = _override ??
        Directory(
          p.join((await getApplicationSupportDirectory()).path, 'vitalup_cache'),
        );
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Returns the value for [key], fetching it with [remote] when the cached
  /// copy is older than [maxAge] (or [forceRefresh] is set).
  ///
  /// [encode] turns the value into JSON-encodable data; [decode] reverses
  /// it. Both default to identity for values that are already plain JSON.
  Future<T> fetch<T>(
    String key, {
    required Future<T> Function() remote,
    required Duration maxAge,
    Object? Function(T value)? encode,
    T Function(Object? json)? decode,
    bool forceRefresh = false,
  }) async {
    final cached = await read<T>(key, decode: decode);
    if (cached != null && !forceRefresh && cached.age < maxAge) {
      return cached.value;
    }
    // Known offline: don't wait for a request to time out.
    if (cached != null && !_connectivity.hasNetwork) return cached.value;

    try {
      final generation = _generation;
      late final Future<Object?> request;
      request = _inFlight[key] ??= () async {
        final value = await remote().timeout(fetchTimeout);
        _connectivity.reportSuccess();
        final data = encode == null ? value : encode(value);
        if (generation == _generation) await write(key, data);
        return data;
      }().whenComplete(() {
        // Block body on purpose: returning the removed future would make
        // whenComplete wait on itself. Only drop our own entry: a clear()
        // may have let a newer request take the slot.
        if (identical(_inFlight[key], request)) _inFlight.remove(key);
      });
      final json = await request;
      return decode == null ? json as T : decode(json);
    } catch (e) {
      if (isOfflineError(e)) {
        _connectivity.reportFailure();
        if (cached != null) return cached.value;
      }
      rethrow;
    }
  }

  /// The cached value for [key] regardless of age, or null.
  Future<Cached<T>?> read<T>(
    String key, {
    T Function(Object? json)? decode,
  }) async {
    final entry = _memory[key] ?? await _load(key);
    if (entry == null) return null;
    try {
      final value = decode == null ? entry.value as T : decode(entry.value);
      return Cached(value, entry.savedAt);
    } catch (e) {
      // Shape changed between app versions: treat as missing.
      debugPrint('CacheStore: dropping unreadable "$key": $e');
      await remove(key);
      return null;
    }
  }

  /// Stores [data] (JSON-encodable) under [key].
  Future<void> write(String key, Object? data) async {
    final entry = Cached<Object?>(data, DateTime.now());
    _memory[key] = entry;
    try {
      final file = await _file(key);
      // Write then rename, so a crash mid-write never leaves half a file.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({'t': entry.savedAt.millisecondsSinceEpoch, 'v': data}),
        flush: true,
      );
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('CacheStore: failed to persist "$key": $e');
    }
  }

  /// Updates the cached value in place (e.g. after a local edit) without a
  /// request. No-op when nothing is cached.
  Future<void> update(String key, Object? Function(Object? data) change) async {
    final entry = _memory[key] ?? await _load(key);
    if (entry == null) return;
    final Object? changed;
    try {
      changed = change(entry.value);
    } catch (e) {
      // Cached shape no longer matches: drop it, the next fetch refills it.
      debugPrint('CacheStore: dropping "$key", update failed: $e');
      await remove(key);
      return;
    }
    await write(key, changed);
  }

  Future<void> remove(String key) async {
    _memory.remove(key);
    try {
      final file = await _file(key);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Removes every key starting with [prefix].
  Future<void> removeWhere(String prefix) async {
    _memory.removeWhere((k, _) => k.startsWith(prefix));
    final encoded = _fileName(prefix).split('.').first;
    try {
      final dir = await _directory();
      await for (final f in dir.list()) {
        if (f is File && p.basename(f.path).startsWith(encoded)) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('CacheStore: failed to clear "$prefix": $e');
    }
  }

  /// Drops everything (sign-out / account deletion).
  Future<void> clear() async {
    _generation++;
    _memory.clear();
    _inFlight.clear();
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    _dir = null;
  }

  Future<Cached<Object?>?> _load(String key) async {
    try {
      final file = await _file(key);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      final savedAt = raw is Map ? raw['t'] : null;
      if (raw is! Map || savedAt is! num || !raw.containsKey('v')) {
        throw const FormatException('unexpected cache file shape');
      }
      final entry = Cached<Object?>(
        raw['v'],
        DateTime.fromMillisecondsSinceEpoch(savedAt.toInt()),
      );
      return _memory[key] = entry;
    } catch (e) {
      // Corrupt or truncated file (e.g. the app was killed mid-write): drop
      // it so the next fetch starts clean.
      debugPrint('CacheStore: dropping unreadable "$key": $e');
      await remove(key);
      return null;
    }
  }

  Future<File> _file(String key) async =>
      File(p.join((await _directory()).path, _fileName(key)));

  /// Readable, filesystem-safe name. Characters are escaped rather than
  /// hashed so [removeWhere] can match by prefix.
  static String _fileName(String key) {
    final buffer = StringBuffer();
    for (final unit in utf8.encode(key)) {
      final c = String.fromCharCode(unit);
      if (RegExp(r'[A-Za-z0-9_\-]').hasMatch(c)) {
        buffer.write(c);
      } else {
        buffer.write('%${unit.toRadixString(16).padLeft(2, '0')}');
      }
    }
    return '$buffer.json';
  }
}
