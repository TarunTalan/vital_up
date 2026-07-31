abstract class MapTileRepository {
  Future<bool> checkRegionDownloaded(String regionId);
  Stream<double> downloadRegion(String regionId, double latitude, double longitude, double radiusKm);
  Future<void> deleteRegion(String regionId);
}
