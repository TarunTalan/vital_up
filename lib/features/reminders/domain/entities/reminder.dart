import 'package:equatable/equatable.dart';

/// What a reminder is about; decides its icon, colour and default screen.
enum ReminderKind {
  activity('activity', 'activity-tracking'),
  meal('meal', 'food-scan'),
  water('water', 'water-trends'),
  sleep('sleep', 'sleep-trends'),
  mood('mood', 'stress-trends'),
  weight('weight', 'weight-trends'),
  custom('custom', null);

  final String code;

  /// Route name a tap opens (see `notificationLinkableRoutes`).
  final String? defaultRoute;

  const ReminderKind(this.code, this.defaultRoute);

  static ReminderKind fromCode(String? code) =>
      values.where((k) => k.code == code).firstOrNull ?? custom;
}

/// A wall-clock time of day, in the device's time zone.
class ReminderTime extends Equatable implements Comparable<ReminderTime> {
  final int hour;
  final int minute;

  const ReminderTime(this.hour, this.minute);

  /// Minutes since midnight, wrapped into a single day.
  factory ReminderTime.fromMinutes(int minutes) {
    final m = minutes % (24 * 60);
    return ReminderTime(m ~/ 60, m % 60);
  }

  /// Parses `HH:mm`; throws [FormatException] when it isn't a valid time.
  factory ReminderTime.parse(String value) =>
      tryParse(value) ?? (throw FormatException('Invalid time', value));

  /// Parses `HH:mm`, or null when it isn't a valid time of day.
  static ReminderTime? tryParse(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return ReminderTime(h, m);
  }

  int get inMinutes => hour * 60 + minute;

  /// `HH:mm`, also the stored form.
  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(ReminderTime other) => inMinutes.compareTo(other.inMinutes);

  @override
  List<Object?> get props => [hour, minute];
}

/// One reminder: fixed [times], or every [intervalMinutes] between
/// [windowStart] and [windowEnd]. Repeats on [weekdays]
/// (`DateTime.monday`..`DateTime.sunday`).
class Reminder extends Equatable {
  static const allWeekdays = {1, 2, 3, 4, 5, 6, 7};

  final String id;
  final ReminderKind kind;
  final String title;
  final String body;
  final List<ReminderTime> times;
  final Set<int> weekdays;
  final bool enabled;
  final bool isPreset;

  /// Route name a tap opens; null opens the app only.
  final String? route;

  final int? intervalMinutes;
  final ReminderTime? windowStart;
  final ReminderTime? windowEnd;

  const Reminder({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.times = const [],
    this.weekdays = allWeekdays,
    this.enabled = false,
    this.isPreset = false,
    this.route,
    this.intervalMinutes,
    this.windowStart,
    this.windowEnd,
  });

  bool get isInterval =>
      intervalMinutes != null && windowStart != null && windowEnd != null;

  bool get isDaily => weekdays.length == 7;

  /// Every time of day this reminder fires, sorted and without duplicates.
  /// An interval window that ends before it starts runs past midnight.
  List<ReminderTime> get firingTimes {
    if (isInterval) {
      final step = intervalMinutes!.clamp(30, 24 * 60);
      final start = windowStart!.inMinutes;
      var end = windowEnd!.inMinutes;
      if (end < start) end += 24 * 60;
      return {
        for (var m = start; m <= end; m += step) ReminderTime.fromMinutes(m),
      }.toList()
        ..sort();
    }
    return times.toSet().toList()..sort();
  }

  Reminder copyWith({
    String? title,
    String? body,
    List<ReminderTime>? times,
    Set<int>? weekdays,
    bool? enabled,
    String? Function()? route,
    int? intervalMinutes,
    ReminderTime? windowStart,
    ReminderTime? windowEnd,
  }) => Reminder(
    id: id,
    kind: kind,
    title: title ?? this.title,
    body: body ?? this.body,
    times: times ?? this.times,
    weekdays: weekdays ?? this.weekdays,
    enabled: enabled ?? this.enabled,
    isPreset: isPreset,
    route: route != null ? route() : this.route,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    windowStart: windowStart ?? this.windowStart,
    windowEnd: windowEnd ?? this.windowEnd,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.code,
    'title': title,
    'body': body,
    'times': [for (final t in times) t.label],
    'weekdays': (weekdays.toList()..sort()),
    'enabled': enabled,
    'is_preset': isPreset,
    'route': route,
    'interval_minutes': intervalMinutes,
    'window_start': windowStart?.label,
    'window_end': windowEnd?.label,
  };

  /// Tolerates bad stored values: unknown times and days are dropped and
  /// odd intervals clamped. Throws [FormatException] only without an id.
  factory Reminder.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Reminder without an id');
    }
    ReminderTime? time(Object? v) => v is String ? ReminderTime.tryParse(v) : null;
    String text(Object? v) => v is String ? v : '';
    final times = json['times'];
    final days = json['weekdays'];
    final interval = json['interval_minutes'];
    return Reminder(
      id: id,
      kind: ReminderKind.fromCode(json['kind'] is String ? json['kind'] as String : null),
      title: text(json['title']),
      body: text(json['body']),
      times: [
        for (final t in (times is List ? times : const []))
          ?time(t),
      ],
      weekdays: {
        for (final d in (days is List ? days : allWeekdays))
          if (d is num && d >= DateTime.monday && d <= DateTime.sunday)
            d.toInt(),
      },
      enabled: json['enabled'] == true,
      isPreset: json['is_preset'] == true,
      route: json['route'] is String ? json['route'] as String : null,
      intervalMinutes: interval is num ? interval.toInt().clamp(30, 24 * 60) : null,
      windowStart: time(json['window_start']),
      windowEnd: time(json['window_end']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    title,
    body,
    times,
    weekdays,
    enabled,
    isPreset,
    route,
    intervalMinutes,
    windowStart,
    windowEnd,
  ];
}
