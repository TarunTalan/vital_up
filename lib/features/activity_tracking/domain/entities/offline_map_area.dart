import 'dart:math';

/// A square of map saved on the device, so the workout map draws there
/// with no connection. GPS, the timer and saving a workout never need the
/// network; only the map does.
///
/// Two kinds: the area around the user, kept automatically ([isAuto]),
/// and areas the user picks on the map (trips, trails).
class OfflineMapArea {
  final String id;

  /// Shown in the list; the automatic one is "Around you".
  final String name;
  final double latitude;
  final double longitude;

  /// Half the square's side.
  final double radiusKm;
  final bool isAuto;

  /// When the download was asked for (null on areas saved before this was
  /// recorded).
  final DateTime? savedAt;

  /// Every tile and the map style are on the device.
  final bool complete;

  /// 0-1 of the tiles on the device.
  final double progress;
  final int sizeBytes;

  const OfflineMapArea({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    this.isAuto = false,
    this.savedAt,
    this.complete = false,
    this.progress = 0,
    this.sizeBytes = 0,
  });

  OfflineMapArea copyWith({bool? complete, double? progress, int? sizeBytes}) =>
      OfflineMapArea(
        id: id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        isAuto: isAuto,
        savedAt: savedAt,
        complete: complete ?? this.complete,
        progress: progress ?? this.progress,
        sizeBytes: sizeBytes ?? this.sizeBytes,
      );

  /// Whether a complete area still has [marginKm] of map around the spot
  /// (so a workout that starts there doesn't run off the map at once).
  bool covers(
    double lat,
    double lng, {
    double marginKm = OfflineMapRules.coverMarginKm,
  }) {
    if (!complete) return false;
    const kmPerDegreeLat = 111.0;
    final kmPerDegreeLng = max(1.0, kmPerDegreeLat * cos(latitude * pi / 180));
    final northSouth = (lat - latitude).abs() * kmPerDegreeLat;
    var lngDelta = (lng - longitude).abs();
    if (lngDelta > 180) lngDelta = 360 - lngDelta;
    final eastWest = lngDelta * kmPerDegreeLng;
    final inner = radiusKm - marginKm;
    return northSouth <= inner && eastWest <= inner;
  }
}

/// Limits for offline map areas (pure, unit-tested).
abstract final class OfflineMapRules {
  /// The automatic area: 20 x 20 km around the user.
  static const double autoRadiusKm = 10;

  /// A picked area is the square in the frame: 2 x 2 km to 30 x 30 km.
  /// Larger squares at street detail run to hundreds of MB.
  static const double minRadiusKm = 1;
  static const double maxRadiusKm = 15;

  /// Mapbox allows 750 tile packs a device; ten areas stay well inside.
  static const int maxSavedAreas = 10;

  static const double coverMarginKm = 3;

  /// Map detail kept offline: whole towns down to streets and paths.
  static const int minZoom = 10;
  static const int maxZoom = 16;

  /// Mapbox zoom 0 shows the world in 512 logical px.
  static const double _earthCircumferenceM = 40075016.686;

  /// Metres one logical pixel covers at [zoom] and [latitude].
  static double metresPerPixel(double latitude, double zoom) =>
      _earthCircumferenceM * cos(latitude * pi / 180) / (512 * pow(2, zoom));

  /// Half the side, in km, of a square [framePx] logical pixels wide.
  static double radiusForFrame({
    required double framePx,
    required double latitude,
    required double zoom,
  }) => framePx / 2 * metresPerPixel(latitude, zoom) / 1000;

  /// "20 × 20 km", "2.5 × 2.5 km".
  static String sideLabel(double radiusKm) {
    final side = radiusKm * 2;
    final text = side >= 10
        ? side.round().toString()
        : (side * 10).floorToDouble() % 10 == 0
        ? side.floor().toString()
        : ((side * 10).floor() / 10).toString();
    return '$text × $text km';
  }

  /// "38 MB", "850 KB", "1.2 GB".
  static String sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).round()} MB';
    }
    return '${max(1, (bytes / 1024).round())} KB';
  }
}
