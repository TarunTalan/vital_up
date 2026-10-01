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
    final days = reminder.weekdays.isEmpty || reminder.isDaily
        ? const <int?>[null]
        : (reminder.weekdays.toList()..sort());
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
