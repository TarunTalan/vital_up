import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/charts/trend_bar_chart.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

import '../../helpers/pump_app.dart';

TrendSeries _week({double? goal, GoalDirection? direction}) => TrendSeries(
  [
    for (var i = 0; i < 7; i++)
      DailyPoint(DateTime(2026, 10, 12 + i), i == 3 ? null : 1000.0 + i),
  ],
  goal: goal,
  direction: direction ?? GoalDirection.up,
);

Future<void> _pump(WidgetTester tester, TrendSeries series) => pumpPage(
  tester,
  Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(AppDimens.gutter),
      child: TrendBarChart(
        series: series,
        color: AppColors.activitySteps,
        valueFormatter: (v) => '${v.round()}',
        axisFormatter: (v) => '${v.round()}',
      ),
    ),
  ),
);

/// The bar for the [i]th day (its tap target).
Finder _bar(int i) => find.byType(GestureDetector).at(i);

void main() {
  testWidgets("only today's value is shown", (tester) async {
    await _pump(tester, _week());
    expect(find.text('1006'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.text('${1000 + i}'), findsNothing);
    }
  });

  testWidgets('a tap shows that day instead, a second tap goes back', (
    tester,
  ) async {
    await _pump(tester, _week());
    await tester.tap(_bar(1));
    await tester.pumpAndSettle();
    expect(find.text('1001'), findsOneWidget);
    expect(find.text('1006'), findsNothing);

    await tester.tap(_bar(1));
    await tester.pumpAndSettle();
    expect(find.text('1006'), findsOneWidget);
    expect(find.text('1001'), findsNothing);
  });

  testWidgets('a tapped empty day says there is no data', (tester) async {
    await _pump(tester, _week());
    await tester.tap(_bar(3));
    await tester.pumpAndSettle();
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('the goal line is labelled, a limit as a limit', (tester) async {
    await _pump(tester, _week(goal: 1003));
    expect(find.text('Goal 1003'), findsOneWidget);

    await _pump(tester, _week(goal: 1003, direction: GoalDirection.down));
    expect(find.text('Limit 1003'), findsOneWidget);
  });

  testWidgets('new data starts again from today', (tester) async {
    await _pump(tester, _week());
    await tester.tap(_bar(1));
    await tester.pumpAndSettle();
    await _pump(tester, _week(goal: 2000));
    expect(find.text('1006'), findsOneWidget);
    expect(find.text('1001'), findsNothing);
  });

  testWidgets('every label is whole at the largest text size', (tester) async {
    await pumpPage(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppDimens.gutter),
          child: TrendBarChart(
            series: _week(goal: 1003),
            color: AppColors.activitySteps,
            valueFormatter: (v) => '${v.round()} steps',
          ),
        ),
      ),
      textScale: kMaxTextScale,
    );
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);
  });
}
