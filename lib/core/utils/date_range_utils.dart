/// Local-time day/week windows shared by dashboard trends and goals.
///
/// Day boundaries are built with `DateTime(y, m, d + 1)` rather than adding
/// 24h, so they stay correct across DST changes.
DateTime startOfDay(DateTime d) {
  final local = d.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);

/// Monday 00:00 of the week containing [d].
DateTime startOfWeek(DateTime d) {
  final day = startOfDay(d);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

/// The last [n] days, oldest first, ending with today.
List<DateTime> lastNDays(int n, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  return [
    for (var i = n - 1; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
}

bool isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Groups [items] by the local day of [dateOf].
Map<DateTime, List<T>> bucketByDay<T>(
  Iterable<T> items,
  DateTime Function(T item) dateOf,
) {
  final buckets = <DateTime, List<T>>{};
  for (final item in items) {
    buckets.putIfAbsent(startOfDay(dateOf(item)), () => []).add(item);
  }
  return buckets;
}
