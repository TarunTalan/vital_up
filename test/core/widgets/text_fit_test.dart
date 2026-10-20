// Home tiles and trend charts show every label whole on narrow and wide
// phones at every text size the app allows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/charts/trend_bar_chart.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

import '../../helpers/pump_app.dart';

Widget _tile(
  TrackerMetric metric,
  String value,
  String goal, {
  TrackerStatus status = TrackerStatus.onTrack,
  String? statusLabel,
  String action = 'Log',
}) => TrackerCard(
  metric: metric,
  status: status,
  statusLabel: statusLabel,
  onOpen: () {},
  actions: [
    TrackerQuickAction(
      label: action,
      icon: Icons.add_rounded,
      color: metric.color,
      filled: true,
      onTap: () {},
    ),
  ],
  child: TrackerProgress(
    value: value,
    goal: goal,
    fraction: 0.6,
    color: metric.color,
  ),
);

TrendSeries _series(int days, {double? goal}) {
  final end = DateTime(2026, 10, 18);
  const values = <double>[6200, 8450, 10230, 4300, 12000, 7600, 9100];
  return TrendSeries([
    for (var i = days - 1; i >= 0; i--)
      DailyPoint(
        DateTime(end.year, end.month, end.day - i),
        values[i % values.length],
      ),
  ], goal: goal);
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(AppDimens.gutter),
      children: [
        TrackerTilePair(
          left: _tile(
            TrackerMetric.water,
            '1.5 L',
            '2.5 L',
            action: 'Log water',
          ),
          right: _tile(
            TrackerMetric.weight,
            '72.4 kg',
            '68.0 kg',
            status: TrackerStatus.done,
            statusLabel: 'Logged today',
            action: 'Update',
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        AppCard(
          child: TrendBarChart(
            series: _series(7, goal: 10000),
            color: AppColors.activitySteps,
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        AppCard(
          child: TrendBarChart(
            series: _series(7),
            color: AppColors.activitySteps,
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        AppCard(
          child: TrendBarChart(
            series: _series(35).weekly(),
            color: AppColors.activitySteps,
            weekly: true,
          ),
        ),
      ],
    ),
  );
}

void main() {
  for (final width in [360.0, 412.0]) {
    for (final scale in [0.85, 1.0, 1.15, 1.3, kMaxTextScale]) {
      testWidgets('tiles and charts whole at ${width.toInt()} dp, $scale', (
        tester,
      ) async {
        await pumpPage(
          tester,
          const _Preview(),
          textScale: scale,
          size: Size(width, 1400),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(takeAllExceptions(tester), isEmpty);
        expect(truncatedTexts(tester), isEmpty);
      });
    }
  }
}
