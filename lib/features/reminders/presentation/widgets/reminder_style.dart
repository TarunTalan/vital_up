import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';

extension ReminderKindStyle on ReminderKind {
  IconData get icon => switch (this) {
    ReminderKind.activity => Icons.directions_run_rounded,
    ReminderKind.meal => Icons.restaurant_rounded,
    ReminderKind.water => Icons.water_drop_rounded,
    ReminderKind.sleep => Icons.bedtime_rounded,
    ReminderKind.mood => Icons.self_improvement_rounded,
    ReminderKind.weight => Icons.monitor_weight_rounded,
    ReminderKind.custom => Icons.alarm_rounded,
  };

  /// Null uses the theme's primary colour.
  Color? get color => switch (this) {
    ReminderKind.activity => AppColors.activitySteps,
    ReminderKind.meal => AppColors.scoreNutrition,
    ReminderKind.water => AppColors.water,
    ReminderKind.sleep => AppColors.sleep,
    ReminderKind.mood => AppColors.blobPurple,
    ReminderKind.weight => AppColors.teal,
    ReminderKind.custom => null,
  };
}

/// Screens a custom reminder can open, as (label, route name).
const reminderTargets = <(String, String?)>[
  ('Just open the app', null),
  ('Log a meal', 'food-scan'),
  ('Water', 'water-trends'),
  ('Sleep', 'sleep-trends'),
  ('Mood check-in', 'stress-trends'),
  ('Start an activity', 'activity-tracking'),
  ('Activity goals', 'activity-goals'),
  ('Weigh in', 'weight-trends'),
];

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Single-letter label for weekday chips (1 = Monday).
String weekdayLetter(int day) => _dayLetters[day - 1];

/// "Daily · 08:30", "Weekdays · 07:00, 18:00",
/// "Every 2 h · 09:00–21:00", "Mon, Wed · 18:00".
String reminderSummary(Reminder r) {
  final days = switch (r.weekdays) {
    final d when d.length == 7 || d.isEmpty => 'Daily',
    final d when d.length == 5 && !d.contains(6) && !d.contains(7) =>
      'Weekdays',
    final d when d.length == 2 && d.contains(6) && d.contains(7) => 'Weekends',
    final d => (d.toList()..sort()).map((x) => _dayNames[x - 1]).join(', '),
  };
  if (r.isInterval) {
    return '${intervalLabel(r.intervalMinutes!)} · '
        '${r.windowStart!.label}–${r.windowEnd!.label}'
        '${days == 'Daily' ? '' : ' · $days'}';
  }
  return '$days · ${r.firingTimes.map((t) => t.label).join(', ')}';
}

String intervalLabel(int minutes) => minutes % 60 == 0
    ? 'Every ${minutes ~/ 60} h'
    : minutes < 60
    ? 'Every $minutes min'
    : 'Every ${minutes ~/ 60} h ${minutes % 60} min';
