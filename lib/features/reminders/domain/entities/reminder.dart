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

  factory ReminderTime.fromMinutes(int minutes) =>
      ReminderTime(minutes ~/ 60, minutes % 60);

  /// Parses `HH:mm`.
  factory ReminderTime.parse(String value) {
    final parts = value.split(':');
    return ReminderTime(int.parse(parts[0]), int.parse(parts[1]));
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
  List<ReminderTime> get firingTimes {
    if (isInterval) {
      final step = intervalMinutes!.clamp(30, 24 * 60);
      return [
        for (
          var m = windowStart!.inMinutes;
          m <= windowEnd!.inMinutes;
          m += step
        )
          ReminderTime.fromMinutes(m),
      ];
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

  factory Reminder.fromJson(Map<String, dynamic> json) {
    ReminderTime? time(Object? v) => v is String ? ReminderTime.parse(v) : null;
    return Reminder(
      id: json['id'] as String,
      kind: ReminderKind.fromCode(json['kind'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      times: [
        for (final t in (json['times'] as List? ?? const []))
          ReminderTime.parse(t as String),
      ],
      weekdays: {
        for (final d in (json['weekdays'] as List? ?? allWeekdays))
          (d as num).toInt(),
      },
      enabled: json['enabled'] as bool? ?? false,
      isPreset: json['is_preset'] as bool? ?? false,
      route: json['route'] as String?,
      intervalMinutes: (json['interval_minutes'] as num?)?.toInt(),
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
