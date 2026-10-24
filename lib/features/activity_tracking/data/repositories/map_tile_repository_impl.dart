import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:vital_up/features/activity_tracking/data/services/map_download_notification.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/offline_map_area.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';

class MapTileRepositoryImpl implements MapTileRepository {
  /// Shows download progress in the notification tray; null in tests.
  final MapDownloadNotifier? _notifier;

  MapTileRepositoryImpl([this._notifier]);

  /// The style the tracking map renders. Tiles alone can't draw a map
  /// offline: the style JSON, sprites and fonts live in a separate style
  /// pack that must be downloaded too.
  static const String _styleUri = MapboxStyles.MAPBOX_STREETS;

  /// Share of the progress bar given to the style pack; tiles get the rest.
  static const double _styleShare = 0.1;

  @override
  Future<List<OfflineMapArea>> areas() async {
    try {
      final tileStore = await TileStore.createDefault();
      final regions = await tileStore.allTileRegions();
      if (regions.isEmpty) return const [];
      final styleReady = await _styleReady();
      final areas = <OfflineMapArea>[];
      for (final region in regions) {
        final Map<String, Object> meta;
        try {
          meta = await tileStore.tileRegionMetadata(region.id);
        } catch (_) {
          continue;
        }
        final area = _areaFrom(region.id, meta);
        if (area == null) continue;
        final required = region.requiredResourceCount;
        final done = region.completedResourceCount;
        areas.add(
          area.copyWith(
            complete: styleReady && required > 0 && done >= required,
            progress: required > 0 ? (done / required).clamp(0.0, 1.0) : 0,
            sizeBytes: region.completedResourceSize,
          ),
        );
      }
      return areas;
    } catch (e) {
      debugPrint('Reading offline maps failed: $e');
      return const [];
    }
  }

  Future<bool> _styleReady() async {
    try {
      final offlineManager = await OfflineManager.create();
      final packs = await offlineManager.allStylePacks();
      return packs.any(
        (p) =>
            p.styleURI == _styleUri &&
            p.requiredResourceCount > 0 &&
            p.completedResourceCount >= p.requiredResourceCount,
      );
    } catch (_) {
      return false;
    }
  }

  /// Regions saved before names were recorded have only the centre and
  /// radius: they were the automatic area.
  static OfflineMapArea? _areaFrom(String id, Map<String, Object> meta) {
    final lat = (meta['lat'] as num?)?.toDouble();
    final lng = (meta['lng'] as num?)?.toDouble();
    final radiusKm = (meta['radiusKm'] as num?)?.toDouble();
    if (lat == null || lng == null || radiusKm == null) return null;
    final isAuto = meta['kind'] != 'saved';
    final savedAt = (meta['savedAt'] as num?)?.toInt();
    return OfflineMapArea(
      id: id,
      name: isAuto ? 'Around you' : (meta['name'] as String? ?? 'Map area'),
      latitude: lat,
      longitude: lng,
      radiusKm: radiusKm,
      isAuto: isAuto,
      savedAt: savedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(savedAt),
    );
  }

  TileRegionLoadOptions _loadOptions(OfflineMapArea area) {
    // 1° latitude ≈ 111 km everywhere; a degree of longitude shrinks
    // with cos(latitude), so a fixed factor skews the box away from
    // the mid-latitudes.
    const kmPerDegreeLat = 111.0;
    final kmPerDegreeLng = max(
      1.0,
      kmPerDegreeLat * cos(area.latitude * pi / 180.0),
    );
    final latDelta = area.radiusKm / kmPerDegreeLat;
    final lngDelta = area.radiusKm / kmPerDegreeLng;
    final lat = area.latitude;
    final lng = area.longitude;
    final ring = [
      Position(lng - lngDelta, lat - latDelta),
      Position(lng + lngDelta, lat - latDelta),
      Position(lng + lngDelta, lat + latDelta),
      Position(lng - lngDelta, lat + latDelta),
      Position(lng - lngDelta, lat - latDelta),
    ];
    return TileRegionLoadOptions(
      geometry: Polygon(coordinates: [ring]).toJson(),
      metadata: {
        'lat': lat,
        'lng': lng,
        'radiusKm': area.radiusKm,
        'kind': area.isAuto ? 'auto' : 'saved',
        'name': area.name,
        if (area.savedAt case final savedAt?)
          'savedAt': savedAt.millisecondsSinceEpoch,
      },
      descriptorsOptions: [
        TilesetDescriptorOptions(
          styleURI: _styleUri,
          minZoom: OfflineMapRules.minZoom,
          maxZoom: OfflineMapRules.maxZoom,
        ),
      ],
      acceptExpired: true,
      // Mobile data too: the map must be ready for a workout anywhere.
      networkRestriction: NetworkRestriction.NONE,
    );
  }

  @override
  Future<int?> estimateBytes(OfflineMapArea area) async {
    try {
      final tileStore = await TileStore.createDefault();
      final estimate = await tileStore
          .estimateTileRegion(
            // Its own id: an estimate must not reuse a saved area's shape.
            'estimate_${area.id}',
            _loadOptions(area),
            null,
            null,
          )
          .timeout(const Duration(seconds: 20));
      return estimate.transferSize;
    } catch (e) {
      debugPrint('Offline map estimate failed: $e');
      return null;
    }
  }

  @override
  Stream<double> download(OfflineMapArea area) {
    final controller = StreamController<double>();

    void emit(double value) {
      final progress = value.clamp(0.0, 1.0);
      _notifier?.progress(progress, name: area.isAuto ? null : area.name);
      if (!controller.isClosed) controller.add(progress);
    }

    Future(() async {
      try {
        // 1. Style pack (style JSON, sprites, glyphs), shared by every area.
        final offlineManager = await OfflineManager.create();
        await offlineManager.loadStylePack(
          _styleUri,
          StylePackLoadOptions(
            glyphsRasterizationMode:
                GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
            acceptExpired: true,
          ),
          (progress) {
            if (progress.requiredResourceCount > 0) {
              emit(
                _styleShare *
                    progress.completedResourceCount /
                    progress.requiredResourceCount,
              );
            }
          },
        );
        emit(_styleShare);

        // 2. Tiles for the square. Loading an id again finishes it or
        // brings it up to date.
        final tileStore = await TileStore.createDefault();
        await tileStore.loadTileRegion(area.id, _loadOptions(area), (progress) {
          if (progress.requiredResourceCount > 0) {
            emit(
              _styleShare +
                  (1 - _styleShare) *
                      progress.completedResourceCount /
                      progress.requiredResourceCount,
            );
          }
        });

        emit(1.0);
        await _notifier?.done(name: area.isAuto ? null : area.name);
        await controller.close();
      } catch (e) {
        await _notifier?.cancel();
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    });

    return controller.stream;
  }

  @override
  Future<void> delete(String id) async {
    try {
      final tileStore = await TileStore.createDefault();
      await tileStore.removeRegion(id);
      // The style is shared: it goes with the last area only.
      if ((await tileStore.allTileRegions()).isNotEmpty) return;
      final offlineManager = await OfflineManager.create();
      await offlineManager.removeStylePack(_styleUri);
    } catch (e) {
      debugPrint('Deleting offline map failed: $e');
    }
  }
}
