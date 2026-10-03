import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

void main() {
  group('TrackerStatus.of', () {
    test('no value and no goal is not logged', () {
      expect(TrackerStatus.of(value: null, goal: null), TrackerStatus.notLogged);
    });

    test('a value without a goal asks for one', () {
      expect(TrackerStatus.of(value: 3, goal: null), TrackerStatus.noGoal);
    });

    test('reaching an "at least" goal is done', () {
      expect(TrackerStatus.of(value: 2500, goal: 2500), TrackerStatus.done);
    });

    test('zero progress on an "at least" goal is not logged', () {
      expect(TrackerStatus.of(value: 0, goal: 2500), TrackerStatus.notLogged);
    });

    test('falling well behind the day\'s pace is behind', () {
      expect(
        TrackerStatus.of(value: 500, goal: 2500, paceFraction: 0.75),
        TrackerStatus.behind,
      );
      expect(
        TrackerStatus.of(value: 1800, goal: 2500, paceFraction: 0.75),
        TrackerStatus.onTrack,
      );
    });

    test('going past a "less is better" limit is over', () {
      expect(
        TrackerStatus.of(value: 300, goal: 240, direction: GoalDirection.down),
        TrackerStatus.over,
      );
      expect(
        TrackerStatus.of(value: 120, goal: 240, direction: GoalDirection.down),
        TrackerStatus.onTrack,
      );
    });

    test('"near" goals are done within 10%', () {
      expect(
        TrackerStatus.of(value: 1950, goal: 2000, direction: GoalDirection.near),
        TrackerStatus.done,
      );
      expect(
        TrackerStatus.of(value: 2600, goal: 2000, direction: GoalDirection.near),
        TrackerStatus.over,
      );
    });
  });

  group('TrackerStatus.dayPace', () {
    test('is 0 before 7am and 1 after 11pm', () {
      expect(TrackerStatus.dayPace(DateTime(2026, 1, 1, 6)), 0);
      expect(TrackerStatus.dayPace(DateTime(2026, 1, 1, 23, 30)), 1);
    });

    test('is half way at 3pm', () {
      expect(TrackerStatus.dayPace(DateTime(2026, 1, 1, 15)), 0.5);
    });
  });
}
