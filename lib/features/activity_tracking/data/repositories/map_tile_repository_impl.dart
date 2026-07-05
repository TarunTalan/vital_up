import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';

class MapTileRepositoryImpl implements MapTileRepository {
  @override
  Future<bool> checkRegionDownloaded(String regionId) async {
    try {
      final tileStore = await TileStore.createDefault();
      final regions = await tileStore.allTileRegions();
      for (final region in regions) {
        if (region.id == regionId) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
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

    Future(() async {
      try {
        final tileStore = await TileStore.createDefault();

        // Create a simple bounding box representing the region (approx 10km radius)
        // 1 degree latitude ~ 111km, 1 degree longitude ~ 111 * cos(lat)
        const latDegreePerKm = 1.0 / 111.0;
        final lngDegreePerKm = 1.0 / (111.0 * 0.8); // Appx for mid-latitudes
        final latDelta = radiusKm * latDegreePerKm;
        final lngDelta = radiusKm * lngDegreePerKm;

        // Bounding box as polygon geometry for Mapbox offline download
        final coordinates = [
          [
            [longitude - lngDelta, latitude - latDelta],
            [longitude + lngDelta, latitude - latDelta],
            [longitude + lngDelta, latitude + latDelta],
            [longitude - lngDelta, latitude + latDelta],
            [longitude - lngDelta, latitude - latDelta],
          ]
        ];

        final geometry = Polygon(
          coordinates: coordinates
              .map((ring) => ring.map((c) => Position(c[0], c[1])).toList())
              .toList(),
        );

        final tileRegionLoadOptions = TileRegionLoadOptions(
          geometry: geometry.toJson(),
          descriptorsOptions: [
            TilesetDescriptorOptions(
              styleURI: MapboxStyles.MAPBOX_STREETS,
              minZoom: 10,
              maxZoom: 15,
            )
          ],
          acceptExpired: true,
          networkRestriction: NetworkRestriction.NONE,
        );

        tileStore.loadTileRegion(
          regionId,
          tileRegionLoadOptions,
          (progress) {
            if (!controller.isClosed) {
              final double pct = progress.requiredResourceCount > 0
                  ? progress.completedResourceCount / progress.requiredResourceCount
                  : 0.0;
              controller.add(pct);
            }
          },
        ).then((_) {
          if (!controller.isClosed) {
            controller.add(1.0);
            controller.close();
          }
        }).catchError((err) {
          if (!controller.isClosed) {
            controller.addError(err);
            controller.close();
          }
        });
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          controller.close();
        }
      }
    });

    return controller.stream;
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    try {
      final tileStore = await TileStore.createDefault();
      await tileStore.removeRegion(regionId);
    } catch (_) {}
  }
}
