import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/home_widget/data/widget_data.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

void main() {
  group('HomeWidgetService.routeOf', () {
    String route(String link) => HomeWidgetService.routeOf(Uri.parse(link));

    test('opens the route a widget asks for', () {
      expect(route('vitalup://widget/open?route=water-trends'), 'water-trends');
      expect(route('vitalup://widget/open?route=food-scan'), 'food-scan');
      expect(route('vitalup://widget/open?route=activity-tracking'), 'activity-tracking');
      expect(route('vitalup://widget/open?route=vita-chat'), 'vita-chat');
      expect(route('vitalup://widget/open?route=login'), 'login');
    });

    test('accepts the path Flutter hands GoRouter', () {
      expect(route('/open?route=sleep-trends'), 'sleep-trends');
    });

    test('maps aliases from older widgets', () {
      expect(route('vitalup://widget/open?route=water-log'), 'water-trends');
      expect(route('vitalup://widget/open?feature=home'), 'dashboard');
    });

    test('opens Home for unknown or missing targets', () {
      expect(route('vitalup://widget/open?route=not-a-page'), 'dashboard');
      expect(route('vitalup://widget/open'), 'dashboard');
    });
  });

  group('buildTiles', () {
    const day = '2026-10-08';

    test('shows each figure against its goal', () {
      final tiles = buildTiles(
        const WidgetInputs(
          signedIn: true,
          day: day,
          activityMetric: 'steps',
          activityCurrent: 6240,
          activityTarget: 8000,
          caloriesEaten: 1420,
          caloriesGoal: 2000,
          waterMl: 1250,
          waterGoalMl: 2500,
          sleepMinutes: 430,
          sleepGoalMinutes: 480,
        ),
      );
      final steps = tiles[WidgetMetric.activity]!;
      expect(steps.label, 'Steps');
      expect(steps.value, '6,240');
      expect(steps.detail, 'of 8,000 steps');
      expect(steps.progress, 78);

      final calories = tiles[WidgetMetric.calories]!;
      expect(calories.value, '1,420');
      expect(calories.detail, 'of 2,000 kcal');
      expect(calories.progress, 71);

      final water = tiles[WidgetMetric.water]!;
      expect(water.value, '1.3 L'); // Same rounding as Home.
      expect(water.detail, 'of 2.5 L');
      expect(water.progress, 50);

      final sleep = tiles[WidgetMetric.sleep]!;
      expect(sleep.value, '7h 10m');
      expect(sleep.detail, 'of 8h 0m');
    });

    test('says what is missing instead of showing zero', () {
      final tiles = buildTiles(const WidgetInputs(signedIn: true, day: day));
      expect(tiles[WidgetMetric.activity]!.detail, 'Set a goal');
      expect(tiles[WidgetMetric.sleep]!.value, '—');
      expect(tiles[WidgetMetric.sleep]!.detail, 'Not logged');
      expect(tiles[WidgetMetric.calories]!.detail, 'kcal today');
      expect(tiles[WidgetMetric.mood]!.detail, 'Not checked in');
      expect(tiles[WidgetMetric.weight]!.value, '—');
    });

    test('caps progress at 100 and leaves mood and weight without a bar', () {
      final tiles = buildTiles(
        WidgetInputs(
          signedIn: true,
          day: day,
          waterMl: 4000,
          waterGoalMl: 2500,
          moodLevel: 2,
          moodAt: DateTime(2026, 10, 8, 9, 12),
          weightKg: 72.4,
        ),
      );
      expect(tiles[WidgetMetric.water]!.progress, 100);
      expect(tiles[WidgetMetric.mood]!.value, 'Calm');
      expect(tiles[WidgetMetric.mood]!.progress, isNull);
      expect(tiles[WidgetMetric.weight]!.value, '72.4 kg');
      expect(tiles[WidgetMetric.weight]!.progress, isNull);
    });
  });

  group('WidgetInputs.forDay', () {
    test("drops yesterday's daily totals but keeps goals and weight", () {
      const yesterday = WidgetInputs(
        signedIn: true,
        day: '2026-10-07',
        activityMetric: 'steps',
        activityCurrent: 9000,
        activityTarget: 8000,
        caloriesEaten: 1800,
        caloriesGoal: 2000,
        waterMl: 2000,
        sleepMinutes: 420,
        moodLevel: 3,
        weightKg: 72,
      );
      final today = yesterday.forDay('2026-10-08');
      expect(today.day, '2026-10-08');
      expect(today.activityCurrent, isNull);
      expect(today.caloriesEaten, isNull);
      expect(today.waterMl, isNull);
      expect(today.sleepMinutes, isNull);
      expect(today.moodLevel, isNull);
      expect(today.activityTarget, 8000);
      expect(today.caloriesGoal, 2000);
      expect(today.weightKg, 72);
    });

    test('keeps everything on the same day', () {
      const inputs = WidgetInputs(signedIn: true, day: '2026-10-08', waterMl: 500);
      expect(identical(inputs.forDay('2026-10-08'), inputs), isTrue);
    });
  });
}
