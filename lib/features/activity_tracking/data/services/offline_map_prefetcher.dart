import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';

/// Keeps a 10 km offline map around the user so the workout map opens at
/// once and still renders with no connection.
///
/// Checked when the app opens ([prefetchAtStartup]) rather than when a
/// workout starts, and again from the tracking screen's first fix in case
/// the user has moved since. One download at a time; a failed one (offline)
/// is simply tried again next time.
class OfflineMapPrefetcher {
  static const String regionId = 'local_workout_region_10k';
  static const double radiusKm = 10.0;

  final MapTileRepository maps;

  OfflineMapPrefetcher(this.maps);

  Future<void>? _running;

  /// Downloads the region around the user's position, when location is
  /// already allowed. Never asks for permission: this runs at app start,
  /// before the user has opened anything that needs location.
  Future<void> prefetchAtStartup() async {
    if (!_hasMapToken) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      // The last known fix is instant and close enough for a 10 km area;
      // a fresh one only when the device has none. This is a one-off
      // request, not the position stream workouts use.
      final position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
            ),
          );
      await ensureAround(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Offline map prefetch skipped: $e');
    }
  }

  /// Downloads the region unless the saved one still covers this spot.
  /// Joins a download already running instead of starting a second one.
  Future<void> ensureAround(double latitude, double longitude) {
    if (!_hasMapToken) return Future.value();
    return _running ??= _ensure(latitude, longitude).whenComplete(() {
      _running = null;
    });
  }

  Future<void> _ensure(double latitude, double longitude) async {
    try {
      if (await maps.regionCovers(regionId, latitude, longitude)) return;
      await maps
          .downloadRegion(regionId, latitude, longitude, radiusKm)
          .drain<void>();
    } catch (e) {
      debugPrint('Offline map download skipped: $e');
    }
  }

  bool get _hasMapToken => SupabaseConfig.mapboxAccessToken.startsWith('pk.');
}
