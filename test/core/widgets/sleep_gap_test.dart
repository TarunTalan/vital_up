import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/widgets/circular_sleep_clock.dart';

void main() {
  const min = 30, max = 18 * 60;
  int clamp(int gap, int previous) =>
      clampSleepGap(gap, previous: previous, min: min, max: max);

  group('sleepGapMinutes', () {
    test('across midnight', () {
      expect(
        sleepGapMinutes(
          const TimeOfDay(hour: 23, minute: 15),
          const TimeOfDay(hour: 6, minute: 40),
        ),
        445,
      );
    });
    test('same day', () {
      expect(
        sleepGapMinutes(
          const TimeOfDay(hour: 1, minute: 0),
          const TimeOfDay(hour: 9, minute: 0),
        ),
        480,
      );
    });
    test('equal times are a zero gap, never 24 h', () {
      expect(
        sleepGapMinutes(
          const TimeOfDay(hour: 7, minute: 0),
          const TimeOfDay(hour: 7, minute: 0),
        ),
        0,
      );
    });
  });

  group('clampSleepGap', () {
    test('keeps a valid night', () => expect(clamp(445, 450), 445));
    test('the limits themselves are allowed', () {
      expect(clamp(min, 40), min);
      expect(clamp(max, 1000), max);
    });
    test('equal times stop at the shortest night', () {
      expect(clamp(0, 35), min);
    });
    test('pushing a handle past the other stops it, no jump', () {
      // Wrapped right round (gap now ~24 h) coming from a short night.
      expect(clamp(1435, 35), min);
    });
    test('stretching past the longest night stops there', () {
      expect(clamp(1100, 1075), max);
      // A fast swipe that wrapped past it is still the longest night.
      expect(clamp(10, 1080), max);
    });
  });
}
