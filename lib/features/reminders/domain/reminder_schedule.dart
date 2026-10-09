import 'package:vital_up/core/events/habit_events.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';

/// iOS keeps at most 64 pending notifications per app; leave headroom.
const maxScheduledReminders = 60;

/// One repeating system notification: daily at [time] when [weekday] is
/// null, otherwise weekly on that weekday.
class ScheduledReminder {
  final int id;
  final Reminder reminder;
  final ReminderTime time;
  final int? weekday;

  const ScheduledReminder({
    required this.id,
    required this.reminder,
    required this.time,
    this.weekday,
  });
}

class ReminderSchedulePlan {
  final List<ScheduledReminder> entries;

  /// Entries left out to stay under [maxScheduledReminders].
  final int dropped;

  const ReminderSchedulePlan(this.entries, this.dropped);
}

/// Expands enabled reminders into system notifications with stable ids.
ReminderSchedulePlan planReminders(
  List<Reminder> reminders, {
  int limit = maxScheduledReminders,
}) {
  final entries = <ScheduledReminder>[];
  final used = <int>{};
  var dropped = 0;

  for (final reminder in reminders.where((r) => r.enabled)) {
    // Only real weekdays; a reminder with no days never fires (an unknown
    // day would also loop forever when finding the next instance).
    final valid = reminder.weekdays
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toSet();
    if (valid.isEmpty) continue;
    final days = valid.length == 7
        ? const <int?>[null]
        : (valid.toList()..sort());
    for (final time in reminder.firingTimes) {
      for (final day in days) {
        if (entries.length >= limit) {
          dropped++;
          continue;
        }
        var id = reminderNotificationId(reminder.id, time, day);
        while (!used.add(id)) {
          id = id == _idEnd ? _idBase : id + 1;
        }
        entries.add(
          ScheduledReminder(
            id: id,
            reminder: reminder,
            time: time,
            weekday: day,
          ),
        );
      }
    }
  }
  return ReminderSchedulePlan(entries, dropped);
}

// Reminder ids live in [1e9, 2e9) so they don't collide with push ids
// (inbox row ids) and fit a Java int.
const _idBase = 1000000000;
const _idEnd = 1999999999;

/// Stable across launches (unlike `String.hashCode`): FNV-1a 32-bit.
int reminderNotificationId(String reminderId, ReminderTime time, int? weekday) {
  var hash = 0x811c9dc5;
  for (final unit in '$reminderId|${weekday ?? 0}|${time.label}'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return _idBase + hash % (_idEnd - _idBase + 1);
}

/// Meal preset each meal type quiets (snacks quiet none).
const _mealPresetByType = {
  0: 'preset_breakfast',
  1: 'preset_lunch',
  2: 'preset_dinner',
};

/// Reminders that [event] makes unnecessary for the rest of today.
Set<String> remindersDoneBy(HabitLogged event, List<Reminder> reminders) {
  bool ofKind(Reminder r, ReminderKind kind) => r.enabled && r.kind == kind;
  return switch (event.habit) {
    Habit.water when event.goalReached => {
      for (final r in reminders)
        if (ofKind(r, ReminderKind.water)) r.id,
    },
    Habit.water => const {},
    Habit.meal => {
      if (_mealPresetByType[event.mealType] case final id?)
        if (reminders.any((r) => r.id == id && r.enabled)) id,
    },
    Habit.activity => {
      for (final r in reminders)
        if (ofKind(r, ReminderKind.activity)) r.id,
    },
    Habit.mood => {
      for (final r in reminders)
        if (ofKind(r, ReminderKind.mood)) r.id,
    },
    Habit.weight => {
      for (final r in reminders)
        if (ofKind(r, ReminderKind.weight)) r.id,
    },
    // Last night is logged: morning "how did you sleep" reminders are done;
    // the evening wind-down still applies.
    Habit.sleep => {
      for (final r in reminders)
        if (ofKind(r, ReminderKind.sleep) &&
            r.times.isNotEmpty &&
            r.times.every((t) => t.hour < 12))
          r.id,
    },
  };
}

/// `yyyy-mm-dd` of [t] in local time.
String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';
