import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_bedtime.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/domain/sleep_detection.dart';

/// Wake day for every scenario: Friday 9 Oct 2026.
final _day = DateTime(2026, 10, 9);

/// [hour] on the wake day; negative or fractional hours reach back into
/// the evening before (e.g. -1 is 11 pm).
DateTime _at(num hour) =>
    _day.add(Duration(minutes: (hour * 60).round()));

List<ScreenEvent> _usage(List<(num, num)> onPeriods) => [
  for (final (from, to) in onPeriods) ...[
    ScreenEvent(_at(from), on: true),
    ScreenEvent(_at(to), on: false),
  ],
];

void main() {
  group('estimateSleepFromScreen', () {
    test('picks the overnight screen-off stretch', () {
      final night = estimateSleepFromScreen(
        _usage([(-3, -1), (7, 7.5), (12, 13)]),
        wakeDay: _day,
      )!;
      expect(night.bedTime, _at(-1));
      expect(night.wakeTime, _at(7));
      expect(night.duration, const Duration(hours: 8));
      expect(night.source, SleepDataSource.phone);
    });

    test('bridges a quick check of the phone and counts it as awake', () {
      final night = estimateSleepFromScreen(
        _usage([(-2, -1), (3, 3 + 2 / 60), (7, 8)]),
        wakeDay: _day,
      )!;
      expect(night.bedTime, _at(-1));
      expect(night.wakeTime, _at(7));
      expect(night.awakeMinutes, 2);
      expect(night.duration, const Duration(hours: 7, minutes: 58));
    });

    test('a long use at night splits it and the longer part wins', () {
      final night = estimateSleepFromScreen(
        _usage([(-2, -1), (1, 1.5), (7, 8)]),
        wakeDay: _day,
      )!;
      expect(night.bedTime, _at(1.5));
      expect(night.wakeTime, _at(7));
    });

    test('no night while still asleep or after a sleepless night', () {
      // Screen went off at 11 pm and has not come back on.
      expect(
        estimateSleepFromScreen(
          [ScreenEvent(_at(-1), on: false)],
          wakeDay: _day,
        ),
        isNull,
      );
      // Only short gaps.
      expect(
        estimateSleepFromScreen(
          _usage([(-2, 0), (1, 2), (3, 4), (5, 6)]),
          wakeDay: _day,
        ),
        isNull,
      );
    });

    test('ignores an afternoon nap and gaps from before the evening', () {
      expect(
        estimateSleepFromScreen(
          _usage([(-20, -19), (-15, -12)]),
          wakeDay: _day,
        ),
        isNull,
      );
      final night = estimateSleepFromScreen(
        _usage([(-1, 0), (6, 13), (17, 18)]),
        wakeDay: _day,
      )!;
      expect(night.wakeTime, _at(6));
    });
  });

  group('buildHealthNight', () {
    test('sums stages and leaves out a nap the same day', () {
      final night = buildHealthNight([
        SleepSample(SleepStage.light, _at(-1), _at(2)),
        SleepSample(SleepStage.deep, _at(2), _at(4)),
        SleepSample(SleepStage.awake, _at(4), _at(4.5)),
        SleepSample(SleepStage.rem, _at(4.5), _at(6.5)),
        // Nap.
        SleepSample(SleepStage.asleep, _at(14), _at(15)),
      ])!;
      expect(night.bedTime, _at(-1));
      expect(night.wakeTime, _at(6.5));
      expect(night.duration, const Duration(hours: 7));
      expect(night.deepSleepMinutes, 120);
      expect(night.awakeMinutes, 30);
    });

    test('stages win over a summary "asleep" sample in any order', () {
      final night = buildHealthNight([
        SleepSample(SleepStage.asleep, _at(-1), _at(7)),
        SleepSample(SleepStage.deep, _at(0), _at(2)),
        SleepSample(SleepStage.light, _at(2), _at(6)),
      ])!;
      expect(night.duration, const Duration(hours: 6));
    });

    test('falls back to time in bed minus awake time', () {
      final night = buildHealthNight([
        SleepSample(SleepStage.inBed, _at(-1), _at(7)),
        SleepSample(SleepStage.awake, _at(3), _at(3.5)),
      ])!;
      expect(night.duration, const Duration(hours: 7, minutes: 30));
    });
  });

  group('bedtimeConsistency', () {
    test('uses the spread in minutes, across midnight', () {
      expect(
        bedtimeConsistency([_at(-1), _at(-1), _at(-1)]),
        100,
      );
      // 11 pm and 1 am: one hour either side of midnight.
      expect(bedtimeConsistency([_at(-1), _at(1)]), 80);
      expect(bedtimeConsistency([_at(-0.5), _at(0)]), 95);
    });
  });

  test('a bedtime tap stays open for up to 18 hours', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await writeBedtime(prefs, 'u1', _at(-1));
    expect(readBedtime(prefs, 'u1', _at(7)), _at(-1));
    expect(readBedtime(prefs, 'u2', _at(7)), isNull);
    expect(readBedtime(prefs, 'u1', _at(17.5)), isNull);
    await clearBedtime(prefs, 'u1');
    expect(readBedtime(prefs, 'u1', _at(7)), isNull);
  });
}
