import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/domain/reminder_rules.dart';
import 'package:vital_up/features/reminders/domain/reminder_schedule.dart';

String? _validate({
  bool isCustom = true,
  String title = 'Vitamins',
  Set<int> weekdays = Reminder.allWeekdays,
  bool isInterval = false,
  List<ReminderTime> times = const [ReminderTime(9, 0)],
  int? interval,
  ReminderTime? start,
  ReminderTime? end,
}) => ReminderRules.validate(
  isCustom: isCustom,
  title: title,
  weekdays: weekdays,
  isInterval: isInterval,
  times: times,
  intervalMinutes: interval,
  windowStart: start,
  windowEnd: end,
);

void main() {
  group('ReminderRules.validate', () {
    test('accepts a normal reminder', () => expect(_validate(), isNull));

    test('custom reminders need a name that is not just spaces', () {
      expect(_validate(title: '   '), isNotNull);
      expect(_validate(isCustom: false, title: ''), isNull);
    });

    test('needs at least one real weekday', () {
      expect(_validate(weekdays: {}), isNotNull);
      expect(_validate(weekdays: {0, 9}), isNotNull);
    });

    test('fixed times: none, duplicates and too many are rejected', () {
      expect(_validate(times: const []), isNotNull);
      expect(
        _validate(times: const [ReminderTime(9, 0), ReminderTime(9, 0)]),
        isNotNull,
      );
      expect(
        _validate(times: [for (var h = 0; h < 7; h++) ReminderTime(h, 0)]),
        isNotNull,
      );
    });

    test('interval window must be ordered and longer than the gap', () {
      const nine = ReminderTime(9, 0);
      expect(
        _validate(
          isInterval: true,
          interval: 60,
          start: nine,
          end: const ReminderTime(21, 0),
        ),
        isNull,
      );
      expect(
        _validate(isInterval: true, interval: 60, start: nine, end: nine),
        isNotNull,
      );
      expect(
        _validate(
          isInterval: true,
          interval: 240,
          start: nine,
          end: const ReminderTime(10, 0),
        ),
        isNotNull,
      );
      expect(
        _validate(
          isInterval: true,
          interval: 5,
          start: nine,
          end: const ReminderTime(21, 0),
        ),
        isNotNull,
      );
    });
  });

  test('sanitize cleans text and drops invalid weekdays', () {
    const r = Reminder(
      id: 'c',
      kind: ReminderKind.custom,
      title: '  Take\nvitamins  ',
      weekdays: {1, 8},
    );
    final clean = ReminderRules.sanitize(r);
    expect(clean.title, 'Take vitamins');
    expect(clean.weekdays, {1});
  });

  group('stored data', () {
    test('ReminderTime.tryParse rejects bad times', () {
      expect(ReminderTime.tryParse('07:30'), const ReminderTime(7, 30));
      expect(ReminderTime.tryParse('25:00'), isNull);
      expect(ReminderTime.tryParse('ab'), isNull);
    });

    test('fromJson skips bad times and days instead of failing', () {
      final r = Reminder.fromJson({
        'id': 'x',
        'kind': 'custom',
        'title': 7,
        'times': ['08:00', '99:99', 3],
        'weekdays': [1, 0, 'mon', 8],
        'interval_minutes': 5,
      });
      expect(r.title, '');
      expect(r.times, const [ReminderTime(8, 0)]);
      expect(r.weekdays, {1});
      expect(r.intervalMinutes, 30);
    });

    test('fromJson without an id throws', () {
      expect(() => Reminder.fromJson({'title': 'x'}), throwsFormatException);
    });
  });

  test('a reminder with no valid days schedules nothing', () {
    const r = Reminder(
      id: 'c',
      kind: ReminderKind.custom,
      title: 'x',
      times: [ReminderTime(9, 0)],
      weekdays: {},
      enabled: true,
    );
    expect(planReminders([r]).entries, isEmpty);
  });

  test('interval window past midnight wraps', () {
    const r = Reminder(
      id: 'c',
      kind: ReminderKind.water,
      title: 'x',
      intervalMinutes: 60,
      windowStart: ReminderTime(23, 0),
      windowEnd: ReminderTime(1, 0),
    );
    expect(r.firingTimes, const [
      ReminderTime(0, 0),
      ReminderTime(1, 0),
      ReminderTime(23, 0),
    ]);
  });
}
