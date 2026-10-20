import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/tracker/goal_controls.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/core/widgets/value_ruler.dart';
import '../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Weight goal sheet renders ValueRuler and saves value', (
    tester,
  ) async {
    double? result;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showTrackerGoalSheet(
                  context: context,
                  metric: TrackerMetric.weight,
                  title: 'Goal weight',
                  initial: 70.0,
                  min: 40.0,
                  max: 180.0,
                  step: 0.5,
                  format: (v) => '${v.toStringAsFixed(1)} kg',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(ValueRuler), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('70.0 kg'), findsOneWidget);

    // Tap increase button (+ 0.5 kg)
    await tester.tap(find.byTooltip('Increase'));
    await tester.pumpAndSettle();

    expect(find.text('70.5 kg'), findsOneWidget);

    // Save
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    expect(result, 70.5);
  });

  testWidgets('Water goal sheet renders WaterGoalGauge and preset chips', (
    tester,
  ) async {
    double? result;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showTrackerGoalSheet(
                  context: context,
                  metric: TrackerMetric.water,
                  title: 'Daily water goal',
                  initial: 2000.0,
                  min: 1000.0,
                  max: 5000.0,
                  step: 250.0,
                  format: (v) => '${(v / 1000).toStringAsFixed(1)} L',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(WaterGoalGauge), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('2.0 L'), findsAtLeastNWidgets(1));
    expect(find.text('About 8 glasses of 250 ml'), findsOneWidget);

    // Preset chips should be visible (e.g. 2.5 L)
    expect(find.widgetWithText(GoalPresetChip, '2.5 L'), findsOneWidget);

    // Select preset 2.5 L
    await tester.tap(find.widgetWithText(GoalPresetChip, '2.5 L'));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    expect(result, 2500.0);
  });

  testWidgets('Sleep goal sheet renders SleepGoalDial with sleep cycles', (
    tester,
  ) async {
    double? result;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showTrackerGoalSheet(
                  context: context,
                  metric: TrackerMetric.sleep,
                  title: 'Nightly sleep goal',
                  initial: 480.0,
                  min: 240.0,
                  max: 720.0,
                  step: 30.0,
                  format: (v) => '${(v / 60).toStringAsFixed(1)} hrs',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(SleepGoalDial), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('About 5 sleep cycles'), findsOneWidget);

    // Preset chip for 8.0 hrs
    expect(find.widgetWithText(GoalPresetChip, '8.0 hrs'), findsOneWidget);

    // Tap increase button (+ 30m = 510m / 8.5 hrs)
    await tester.tap(find.byTooltip('Increase'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FitText, '8.5 hrs'), findsOneWidget);

    // Save
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    expect(result, 510.0);
  });

  testWidgets(
    'Screen time goal sheet renders ScreenTimeGoalGauge with wellness zones',
    (tester) async {
      double? result;
      await pumpPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showTrackerGoalSheet(
                    context: context,
                    metric: TrackerMetric.screenTime,
                    title: 'Daily screen time limit',
                    initial: 120.0,
                    min: 30.0,
                    max: 360.0,
                    step: 15.0,
                    format: (v) => '${(v / 60).toStringAsFixed(1)} hrs',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(ScreenTimeGoalGauge), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Within the common 2 hour target'), findsOneWidget);

      // Save
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();

      expect(result, 120.0);
    },
  );
}
