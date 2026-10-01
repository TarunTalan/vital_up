abstract class MapTileRepository {
  Future<bool> checkRegionDownloaded(String regionId);

  /// Whether the downloaded region is complete and still has at least
  /// [marginKm] of map around ([latitude], [longitude]).
  Future<bool> regionCovers(
    String regionId,
    double latitude,
    double longitude, {
    double marginKm,
  });

  Stream<double> downloadRegion(String regionId, double latitude, double longitude, double radiusKm);
  Future<void> deleteRegion(String regionId);
}
