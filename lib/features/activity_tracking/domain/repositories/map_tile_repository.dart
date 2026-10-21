import 'package:vital_up/features/activity_tracking/domain/entities/offline_map_area.dart';

/// Offline map areas on the device (Mapbox tile regions + the style pack).
abstract class MapTileRepository {
  /// Every area saved or being saved, with its progress and size.
  Future<List<OfflineMapArea>> areas();

  /// Download size of [area] in bytes; null when it can't be told
  /// (offline, the estimate failed).
  Future<int?> estimateBytes(OfflineMapArea area);

  /// Downloads [area] (or finishes one that stopped); progress 0-1.
  /// Works over any network.
  Stream<double> download(OfflineMapArea area);

  /// Removes the area; the map style goes with the last one.
  Future<void> delete(String id);
}
