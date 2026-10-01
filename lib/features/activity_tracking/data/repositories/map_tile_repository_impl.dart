import 'dart:async';
import 'dart:math';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';

class MapTileRepositoryImpl implements MapTileRepository {
  /// The style the tracking map renders. Tiles alone can't draw a map
  /// offline: the style JSON, sprites and fonts live in a separate style
  /// pack that must be downloaded too.
  static const String _styleUri = MapboxStyles.MAPBOX_STREETS;

  /// Share of the progress bar given to the style pack; tiles get the rest.
  static const double _styleShare = 0.1;

  @override
  Future<bool> checkRegionDownloaded(String regionId) async {
    try {
      final tileStore = await TileStore.createDefault();
      final regions = await tileStore.allTileRegions();
      final region = regions.where((r) => r.id == regionId).firstOrNull;
      if (region == null ||
          region.requiredResourceCount == 0 ||
          region.completedResourceCount < region.requiredResourceCount) {
        return false;
      }

      final offlineManager = await OfflineManager.create();
      final packs = await offlineManager.allStylePacks();
      return packs.any((p) =>
          p.styleURI == _styleUri &&
          p.requiredResourceCount > 0 &&
          p.completedResourceCount >= p.requiredResourceCount);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> regionCovers(
    String regionId,
    double latitude,
    double longitude, {
    double marginKm = 3.0,
  }) async {
    if (!await checkRegionDownloaded(regionId)) return false;
    try {
      final tileStore = await TileStore.createDefault();
      final meta = await tileStore.tileRegionMetadata(regionId);
      final lat = (meta['lat'] as num?)?.toDouble();
      final lng = (meta['lng'] as num?)?.toDouble();
      final radiusKm = (meta['radiusKm'] as num?)?.toDouble();
      // Regions saved before the centre was recorded: assume they still fit.
      if (lat == null || lng == null || radiusKm == null) return true;
      return _distanceKm(lat, lng, latitude, longitude) <= radiusKm - marginKm;
    } catch (_) {
      return true;
    }
  }

  @override
  Stream<double> downloadRegion(
    String regionId,
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    final controller = StreamController<double>();

    void emit(double value) {
      if (!controller.isClosed) controller.add(value.clamp(0.0, 1.0));
    }

    Future(() async {
      try {
        // 1. Style pack (style JSON, sprites, glyphs).
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
              emit(_styleShare *
                  progress.completedResourceCount /
                  progress.requiredResourceCount);
            }
          },
        );
        emit(_styleShare);

        // 2. Tiles for a box of radiusKm around the user.
        final tileStore = await TileStore.createDefault();

        // 1° latitude ≈ 111 km everywhere; a degree of longitude shrinks
        // with cos(latitude), so a fixed factor skews the box away from
        // the mid-latitudes.
        const kmPerDegreeLat = 111.0;
        final kmPerDegreeLng =
            max(1.0, kmPerDegreeLat * cos(latitude * pi / 180.0));
        final latDelta = radiusKm / kmPerDegreeLat;
        final lngDelta = radiusKm / kmPerDegreeLng;

        final ring = [
          Position(longitude - lngDelta, latitude - latDelta),
          Position(longitude + lngDelta, latitude - latDelta),
          Position(longitude + lngDelta, latitude + latDelta),
          Position(longitude - lngDelta, latitude + latDelta),
          Position(longitude - lngDelta, latitude - latDelta),
        ];

        final tileRegionLoadOptions = TileRegionLoadOptions(
          geometry: Polygon(coordinates: [ring]).toJson(),
          metadata: {'lat': latitude, 'lng': longitude, 'radiusKm': radiusKm},
          descriptorsOptions: [
            TilesetDescriptorOptions(
              styleURI: _styleUri,
              minZoom: 10,
              maxZoom: 16,
            )
          ],
          acceptExpired: true,
          networkRestriction: NetworkRestriction.NONE,
        );

        await tileStore.loadTileRegion(
          regionId,
          tileRegionLoadOptions,
          (progress) {
            if (progress.requiredResourceCount > 0) {
              emit(_styleShare +
                  (1 - _styleShare) *
                      progress.completedResourceCount /
                      progress.requiredResourceCount);
            }
          },
        );

        emit(1.0);
        await controller.close();
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    });

    return controller.stream;
  }

  static double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLng = (lng2 - lng1) * pi / 180.0;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    try {
      final tileStore = await TileStore.createDefault();
      await tileStore.removeRegion(regionId);
      final offlineManager = await OfflineManager.create();
      await offlineManager.removeStylePack(_styleUri);
    } catch (_) {}
  }
}
