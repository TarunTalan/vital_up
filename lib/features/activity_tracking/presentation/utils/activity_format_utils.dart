/// Formats a [Duration] as HH:MM:SS.
String formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// Formats a pace given in seconds-per-km as MM:SS.
String formatPace(int secondsPerKm) {
  if (secondsPerKm <= 0) return '00:00';
  final minutes = (secondsPerKm ~/ 60).toString().padLeft(2, '0');
  final seconds = (secondsPerKm % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Formats a distance given in meters as kilometers with 2 decimal places.
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