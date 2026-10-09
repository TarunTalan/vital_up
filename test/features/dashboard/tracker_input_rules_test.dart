import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/domain/tracker_input_rules.dart';

void main() {
  group('safeFraction', () {
    test('divides by a positive goal', () {
      expect(safeFraction(500, 2000), 0.25);
    });
    test('null for no, zero or negative goal', () {
      expect(safeFraction(500, null), isNull);
      expect(safeFraction(500, 0), isNull);
      expect(safeFraction(500, -10), isNull);
      expect(safeFraction(null, 10), isNull);
    });
    test('null for NaN / infinity', () {
      expect(safeFraction(double.nan, 10), isNull);
      expect(safeFraction(double.infinity, 10), isNull);
    });
  });

  group('parseWaterAmount', () {
    test('accepts whole ml in range', () {
      expect(parseWaterAmount('350'), 350);
      expect(parseWaterAmount(' 1 '), 1);
      expect(parseWaterAmount('5000'), 5000);
    });
    test('rejects empty, zero, too much and fractions', () {
      expect(parseWaterAmount(''), isNull);
      expect(parseWaterAmount('0'), isNull);
      expect(parseWaterAmount('5001'), isNull);
      expect(parseWaterAmount('12.5'), isNull);
      expect(parseWaterAmount('abc'), isNull);
    });
  });

  test('goals fall back when stored values are out of range', () {
    expect(sanitizeWaterGoal(null, fallback: 2500), 2500);
    expect(sanitizeWaterGoal(0, fallback: 2500), 2500);
    expect(sanitizeWaterGoal(3000, fallback: 2500), 3000);
    expect(sanitizeSleepGoal(0, fallback: 480), 480);
    expect(sanitizeSleepGoal(420, fallback: 480), 420);
    expect(sanitizeScreenLimit(-5, fallback: 240), 240);
    expect(sanitizeScreenLimit(120, fallback: 240), 120);
  });

  group('sleep entry', () {
    final wakeDay = DateTime(2026, 3, 10);

    test('bedtime after wake time is the evening before', () {
      final t = sleepEntryTimes(
        wakeDay,
        bedMinutes: 23 * 60,
        wakeMinutes: 7 * 60,
      );
      expect(t.bed, DateTime(2026, 3, 9, 23));
      expect(t.wake, DateTime(2026, 3, 10, 7));
    });

    test('evening before across a month boundary', () {
      final t = sleepEntryTimes(
        DateTime(2026, 3, 1),
        bedMinutes: 22 * 60 + 30,
        wakeMinutes: 6 * 60,
      );
      expect(t.bed, DateTime(2026, 2, 28, 22, 30));
    });

    test('same bed and wake time is a 24h night and is rejected', () {
      final t = sleepEntryTimes(wakeDay, bedMinutes: 420, wakeMinutes: 420);
      expect(
        sleepEntryError(t.bed, t.wake, now: DateTime(2026, 3, 11)),
        isNotNull,
      );
    });

    test('a normal night is accepted', () {
      expect(
        sleepEntryError(
          DateTime(2026, 3, 9, 23),
          DateTime(2026, 3, 10, 7),
          now: DateTime(2026, 3, 10, 9),
        ),
        isNull,
      );
    });

    test('wake-up in the future is rejected', () {
      expect(
        sleepEntryError(
          DateTime(2026, 3, 9, 23),
          DateTime(2026, 3, 10, 7),
          now: DateTime(2026, 3, 10, 6),
        ),
        "Wake-up time can't be in the future.",
      );
    });

    test('too short is rejected', () {
      expect(
        sleepEntryError(
          DateTime(2026, 3, 10, 6, 50),
          DateTime(2026, 3, 10, 7),
          now: DateTime(2026, 3, 10, 9),
        ),
        isNotNull,
      );
    });
  });

  group('TrendSeries ignores non-finite values', () {
    test('NaN entries count as nothing', () {
      final series = TrendSeries.sum<double>(
        days: 2,
        items: [double.nan, 300],
        dateOf: (_) => DateTime.now(),
        valueOf: (v) => v,
      );
      expect(series.today, 300);
      expect(series.average, 300);
    });

    test('average skips NaN points', () {
      final now = DateTime.now();
      final series = TrendSeries([
        DailyPoint(now, double.nan),
        DailyPoint(now, 4),
      ]);
      expect(series.average, 4);
      expect(series.loggedDays, 1);
    });
  });
}
