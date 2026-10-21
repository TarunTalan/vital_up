import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/home_widget/data/widget_data.dart';
import 'package:vital_up/features/weekly_summary/weekly_summary_service.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('services', () {
    test(
      'a removed water goal reads as none, a missing one as 2.5 L',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final water = WaterIntakeService(IsarService(), prefs);
        expect(water.getDailyGoal(), 2500);

        await water.clearDailyGoal();
        expect(water.getDailyGoal(), isNull);
        expect(WaterIntakeService.dailyGoalFrom(prefs), isNull);

        await water.setDailyGoal(3000);
        expect(water.getDailyGoal(), 3000);
      },
    );

    test('a removed sleep goal reads as none', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sleep = SleepService(IsarService(), prefs);
      expect(sleep.getGoalMinutes(), SleepService.defaultGoalMinutes);
      await sleep.clearGoal();
      expect(sleep.getGoalMinutes(), isNull);
    });
  });

  group('home screen widgets', () {
    const day = '2026-10-22';

    test('no goal: the amount with no bar', () {
      final tiles = buildTiles(
        const WidgetInputs(
          signedIn: true,
          day: day,
          waterMl: 1250,
          waterGoalMl: null,
          sleepMinutes: 432,
          sleepGoalMinutes: null,
        ),
      );
      final water = tiles[WidgetMetric.water]!;
      expect(water.detail, 'today');
      expect(water.progress, isNull);
      final sleep = tiles[WidgetMetric.sleep]!;
      expect(sleep.detail, 'last night');
      expect(sleep.progress, isNull);
    });
  });

  group('weekly summary', () {
    test('without a water goal it counts days logged instead', () {
      final stats = weekStats(
        from: DateTime(2026, 9, 28),
        sessions: const [],
        waterByDay: {DateTime(2026, 9, 28): 2600, DateTime(2026, 9, 29): 1200},
        waterGoalMl: null,
        sleep: const [],
        mealTimes: const [],
        weights: const [],
      );
      expect(stats.waterGoalDays, isNull);
      expect(stats.waterDays, 2);
    });
  });

  group('goal sheet', () {
    Future<void> open(
      WidgetTester tester, {
      Future<void> Function()? onRemove,
    }) async {
      await pumpPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showTrackerGoalSheet(
                  context: context,
                  metric: TrackerMetric.water,
                  title: 'Daily water goal',
                  initial: 2500,
                  min: 500,
                  max: 10000,
                  step: 250,
                  format: (v) => '${v.round()} ml',
                  onRemove: onRemove,
                  removeMessage: "Days won't earn Arena points.",
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('no Remove without a goal', (tester) async {
      await open(tester);
      expect(find.text('Remove goal'), findsNothing);
    });

    testWidgets('Remove asks first, then removes and closes', (tester) async {
      var removed = false;
      await open(tester, onRemove: () async => removed = true);

      await tester.tap(find.text('Remove goal'));
      await tester.pumpAndSettle();
      expect(find.text('Remove your water goal?'), findsOneWidget);
      expect(find.text("Days won't earn Arena points."), findsOneWidget);

      // Cancel keeps the goal and the sheet.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(removed, isFalse);
      expect(find.text('Save goal'), findsOneWidget);

      await tester.tap(find.text('Remove goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
      expect(find.text('Save goal'), findsNothing);
    });
  });
}
