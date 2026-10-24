import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/offline_map_area.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';

/// What the offline maps page shows.
@immutable
class OfflineMapsState {
  /// The device's areas have been read at least once.
  final bool loaded;

  /// Areas on the device or waiting to download.
  final List<OfflineMapArea> areas;

  /// The area downloading now and how far it is (0-1).
  final String? downloadingId;
  final double downloadProgress;

  /// Waiting for the download before them.
  final Set<String> queuedIds;

  const OfflineMapsState({
    this.loaded = false,
    this.areas = const [],
    this.downloadingId,
    this.downloadProgress = 0,
    this.queuedIds = const {},
  });

  OfflineMapArea? get auto => areas.where((a) => a.isAuto).firstOrNull;

  /// Areas the user picked, newest first.
  List<OfflineMapArea> get saved => areas.where((a) => !a.isAuto).toList();

  int get totalBytes => areas.fold(0, (sum, a) => sum + a.sizeBytes);

  bool isBusy(String id) => id == downloadingId || queuedIds.contains(id);

  /// A complete area has the map around this spot.
  bool covers(double latitude, double longitude) =>
      areas.any((a) => a.covers(latitude, longitude));
}

/// Offline maps for workouts: GPS, the timer and saving a workout never
/// need a connection, so with the map saved too an outdoor workout works
/// anywhere.
///
/// - The area around the user ("Around you", 20 x 20 km) is kept
///   automatically: checked at app start and from the tracking screen's
///   first fix, downloaded again when the user has moved out of it. Over
///   any network, so it's there before the user is somewhere without one.
///   Can be switched off ([setAutoEnabled]).
/// - Areas the user picks on the map ([download], up to
///   [OfflineMapRules.maxSavedAreas]): trips, trails.
///
/// One download at a time. A download stopped by a lost connection is
/// resumed once the device is back online; one stopped by the app closing
/// is resumed at the next start.
class OfflineMapService {
  /// The automatic area's id (kept from the first version, so existing
  /// installs keep their download).
  static const String autoAreaId = 'local_workout_region_10k';
  static const String autoEnabledKey = 'offline_map_auto_v1';

  final MapTileRepository maps;
  final SharedPreferences prefs;
  final Future<({double latitude, double longitude})?> Function() _locate;
  final bool Function() _hasMapToken;
  final DateTime Function() _now;

  final ValueNotifier<OfflineMapsState> state = ValueNotifier(
    const OfflineMapsState(),
  );

  OfflineMapService(
    this.maps,
    this.prefs, {
    Stream<bool>? onlineChanges,
    Future<({double latitude, double longitude})?> Function()? locate,
    bool Function()? hasMapToken,
    DateTime Function()? now,
  }) : _locate = locate ?? _lastKnownPosition,
       _hasMapToken =
           hasMapToken ??
           (() => SupabaseConfig.mapboxAccessToken.startsWith('pk.')),
       _now = now ?? DateTime.now {
    _online = onlineChanges?.listen((online) {
      if (online) resumeStopped();
    });
  }

  StreamSubscription<bool>? _online;

  List<OfflineMapArea> _stored = const [];

  /// Downloads asked for, in order; the first one is running.
  final List<OfflineMapArea> _queue = [];
  bool _running = false;
  String? _activeId;
  double _progress = 0;

  /// Asked for this session but not on the device yet (a download that
  /// failed before its first tile), so the list still shows them.
  final Map<String, OfflineMapArea> _requested = {};

  /// Bumped by [clearAll]: a download running then is deleted when it ends.
  int _generation = 0;

  Future<void>? _refreshing;

  bool get autoEnabled => prefs.getBool(autoEnabledKey) ?? true;

  /// Re-reads the device's areas.
  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _refresh() async {
    _stored = await maps.areas();
    _requested.removeWhere((id, _) => _stored.any((a) => a.id == id));
    _publish(loaded: true);
  }

  void _publish({bool? loaded}) {
    final areas = <OfflineMapArea>[
      ..._stored,
      ..._requested.values.where((r) => !_stored.any((a) => a.id == r.id)),
    ];
    final shown = [
      for (final area in areas)
        area.id == _activeId ? area.copyWith(progress: _progress) : area,
    ];
    shown.sort((a, b) {
      if (a.isAuto != b.isAuto) return a.isAuto ? -1 : 1;
      final at = a.savedAt?.millisecondsSinceEpoch ?? 0;
      final bt = b.savedAt?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });
    state.value = OfflineMapsState(
      loaded: loaded ?? state.value.loaded,
      areas: List.unmodifiable(shown),
      downloadingId: _activeId,
      downloadProgress: _progress,
      queuedIds: {
        for (final job in _queue)
          if (job.id != _activeId) job.id,
      },
    );
  }

  /// At app start: finishes areas whose download stopped and keeps the
  /// area around the user. Never asks for location: it runs before the
  /// user has opened anything that needs it.
  Future<void> prefetchAtStartup() async {
    if (!_hasMapToken()) return;
    try {
      await refresh();
      resumeStopped();
      if (!autoEnabled) return;
      final position = await _locate();
      if (position == null) return;
      await ensureAround(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Offline map prefetch skipped: $e');
    }
  }

  /// Downloads the area around this spot unless a saved one (automatic or
  /// picked) already has it.
  Future<void> ensureAround(double latitude, double longitude) async {
    if (!_hasMapToken() || !autoEnabled) return;
    if (!state.value.loaded) await refresh();
    if (state.value.covers(latitude, longitude)) return;
    if (_queue.any((job) => job.isAuto)) return;
    _enqueue(
      OfflineMapArea(
        id: autoAreaId,
        name: 'Around you',
        latitude: latitude,
        longitude: longitude,
        radiusKm: OfflineMapRules.autoRadiusKm,
        isAuto: true,
        savedAt: _now(),
      ),
    );
  }

  /// The area as it would be saved, for [MapTileRepository.estimateBytes].
  OfflineMapArea draft({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String name = '',
  }) => OfflineMapArea(
    id: 'area_${_now().millisecondsSinceEpoch}',
    name: name,
    latitude: latitude,
    longitude: longitude,
    radiusKm: radiusKm
        .clamp(OfflineMapRules.minRadiusKm, OfflineMapRules.maxRadiusKm)
        .toDouble(),
    savedAt: _now(),
  );

  /// A name for the next area: "Map area 3".
  String suggestedName() {
    final taken = state.value.saved.map((a) => a.name).toSet();
    var n = state.value.saved.length + 1;
    while (taken.contains('Map area $n')) {
      n++;
    }
    return 'Map area $n';
  }

  /// Whether another area may be saved.
  bool get canSaveMore =>
      state.value.saved.length < OfflineMapRules.maxSavedAreas;

  /// Saves a picked area. Null when it's on its way, otherwise a message
  /// to show.
  String? download(OfflineMapArea draft) {
    if (!_hasMapToken()) return "Maps aren't available in this version.";
    if (!canSaveMore) {
      return 'You can keep ${OfflineMapRules.maxSavedAreas} maps. '
          'Delete one first.';
    }
    final name = sanitizeText(draft.name);
    final area = OfflineMapArea(
      id: draft.id,
      name: name.isEmpty ? suggestedName() : name,
      latitude: draft.latitude,
      longitude: draft.longitude,
      radiusKm: draft.radiusKm,
      savedAt: draft.savedAt ?? _now(),
    );
    _requested[area.id] = area;
    _enqueue(area);
    return null;
  }

  /// Picks up an area whose download stopped.
  void resume(String id) {
    final area = _stored.where((a) => a.id == id).firstOrNull ?? _requested[id];
    if (area == null || area.complete) return;
    _enqueue(area);
  }

  /// Every area that isn't complete and isn't downloading.
  void resumeStopped() {
    for (final area in [..._stored, ..._requested.values]) {
      if (area.complete) continue;
      if (area.isAuto && !autoEnabled) continue;
      _enqueue(area);
    }
  }

  /// Deletes an area (not while it downloads: the map SDK can't stop one).
  Future<void> delete(String id) async {
    if (id == _activeId) return;
    _queue.removeWhere((job) => job.id == id);
    _requested.remove(id);
    _publish();
    await maps.delete(id);
    await refresh();
  }

  /// Off: the area around the user is deleted and no longer kept.
  Future<void> setAutoEnabled(bool enabled) async {
    await prefs.setBool(autoEnabledKey, enabled);
    if (enabled) {
      unawaited(prefetchAtStartup());
      return;
    }
    // A running one is deleted when it ends (see _pump).
    await delete(autoAreaId);
  }

  /// Sign-out: picked areas can name places the user goes.
  Future<void> clearAll() async {
    _generation++;
    _queue.removeWhere((job) => job.id != _activeId);
    _requested.clear();
    for (final area in await maps.areas()) {
      if (area.id != _activeId) await maps.delete(area.id);
    }
    await refresh();
  }

  void _enqueue(OfflineMapArea area) {
    if (_queue.any((job) => job.id == area.id)) return;
    _queue.add(area);
    _publish();
    _pump();
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.first;
        final generation = _generation;
        _activeId = job.id;
        _progress = job.progress;
        _publish();
        try {
          var shownPercent = -1;
          await for (final progress in maps.download(job)) {
            _progress = progress;
            final percent = (progress * 100).floor();
            if (percent != shownPercent) {
              shownPercent = percent;
              _publish();
            }
          }
        } catch (e) {
          // Offline or the connection dropped: resumed once back online.
          debugPrint('Offline map download stopped: $e');
        }
        _queue.remove(job);
        _activeId = null;
        _progress = 0;
        if (generation != _generation || (job.isAuto && !autoEnabled)) {
          _requested.remove(job.id);
          await maps.delete(job.id);
        }
        await refresh();
      }
    } finally {
      _running = false;
      _activeId = null;
      _publish();
    }
  }

  @visibleForTesting
  Future<void> idle() async {
    while (_running || _refreshing != null) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<void> dispose() async {
    await _online?.cancel();
    state.dispose();
  }

  /// The last known fix is instant and close enough for a 20 km area; a
  /// fresh one only when the device has none.
  static Future<({double latitude, double longitude})?>
  _lastKnownPosition() async =>
      await lastKnownFix() ?? await currentFix(LocationAccuracy.medium);

  /// The device's last known fix (instant, may be old). Only with location
  /// already allowed: none of these is ever a reason to ask.
  static Future<({double latitude, double longitude})?> lastKnownFix() =>
      _fix(Geolocator.getLastKnownPosition);

  /// A fresh fix (up to 20 s).
  static Future<({double latitude, double longitude})?> currentFix([
    LocationAccuracy accuracy = LocationAccuracy.high,
  ]) => _fix(
    () => Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: const Duration(seconds: 20),
      ),
    ),
  );

  /// Whether location is on and allowed.
  static Future<bool> canLocate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static Future<({double latitude, double longitude})?> _fix(
    Future<Position?> Function() read,
  ) async {
    try {
      if (!await canLocate()) return null;
      final position = await read();
      if (position == null) return null;
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (e) {
      debugPrint('Offline map: no position: $e');
      return null;
    }
  }
}
