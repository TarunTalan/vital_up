import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';

/// Limits and checks for reminders, shared by the editor, the cubit and
/// stored-data parsing.
abstract final class ReminderRules {
  static const titleMax = InputLimits.shortText;
  static const bodyMax = InputLimits.note;

  /// Most fixed times one reminder can have.
  static const maxTimes = 6;

  /// Interval reminders: shortest and longest gap between nudges.
  static const intervalMin = 30;
  static const intervalMax = 12 * 60;

  /// Interval choices offered by the editor.
  static const intervals = [30, 60, 90, 120, 180, 240];

  static String cleanTitle(String raw) => sanitizeText(raw, maxLength: titleMax);

  static String cleanBody(String raw) =>
      sanitizeText(raw, maxLength: bodyMax, multiline: true);

  /// True for `DateTime.monday`..`DateTime.sunday`.
  static bool isWeekday(int day) => day >= DateTime.monday && day <= DateTime.sunday;

  /// Inline error for an edited reminder, or null when it can be saved.
  static String? validate({
    required bool isCustom,
    required String title,
    required Set<int> weekdays,
    required bool isInterval,
    required List<ReminderTime> times,
    int? intervalMinutes,
    ReminderTime? windowStart,
    ReminderTime? windowEnd,
  }) {
    if (isCustom && cleanTitle(title).isEmpty) {
      return 'Give your reminder a name.';
    }
    if (!weekdays.any(isWeekday)) return 'Pick at least one day.';
    if (isInterval) {
      if (intervalMinutes == null ||
          intervalMinutes < intervalMin ||
          intervalMinutes > intervalMax) {
        return 'Choose how often to remind you.';
      }
      if (windowStart == null || windowEnd == null) {
        return 'Set a start and end time.';
      }
      if (windowEnd.compareTo(windowStart) <= 0) {
        return 'The end time must be after the start time.';
      }
      if (windowEnd.inMinutes - windowStart.inMinutes < intervalMinutes) {
        return 'Make the time window longer than the gap.';
      }
      return null;
    }
    if (times.isEmpty) return 'Add at least one time.';
    if (times.length > maxTimes) return 'Use $maxTimes times or fewer.';
    if (times.toSet().length != times.length) {
      return 'That time is already on the list.';
    }
    return null;
  }

  /// [reminder] with its text cleaned and its days limited to real weekdays.
  static Reminder sanitize(Reminder reminder) => reminder.copyWith(
    title: cleanTitle(reminder.title),
    body: cleanBody(reminder.body),
    weekdays: reminder.weekdays.where(isWeekday).toSet(),
  );
}
