import 'package:vital_up/core/preferences/distance_unit_notifier.dart';

/// Formats a [Duration] as HH:MM:SS.
String formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// Formats a pace given in seconds-per-km as MM:SS, converting to per-mile
/// if [unit] is [DistanceUnit.miles].
String formatPace(int secondsPerKm, {DistanceUnit unit = DistanceUnit.km}) {
  if (secondsPerKm <= 0) return '00:00';
  final pace = unit == DistanceUnit.miles
      ? (secondsPerKm * 1.60934).round()
      : secondsPerKm;
  final minutes = (pace ~/ 60).toString().padLeft(2, '0');
  final seconds = (pace % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Formats distance in meters, converting based on [unit].
/// Returns a display string (e.g. "3.24" km or "2.01" mi).
String formatDistance(double distanceMeters, {DistanceUnit unit = DistanceUnit.km}) {
  if (unit == DistanceUnit.miles) {
    return (distanceMeters / 1609.344).toStringAsFixed(2);
  }
  return (distanceMeters / 1000).toStringAsFixed(2);
}

/// Convenience alias for backwards-compat — formats as km only.
String formatDistanceKm(double distanceMeters) {
  return (distanceMeters / 1000).toStringAsFixed(2);
}

/// Formats a [DateTime] as a short date, e.g. "12 Jul 2026".
String formatShortDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Formats a [DateTime] as a 24h time, e.g. "07:45".
String formatTimeOfDay(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}