class TrackPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double speed;

  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.speed,
  });
}
