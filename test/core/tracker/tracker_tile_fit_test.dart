import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';

import '../../helpers/pump_app.dart';

/// A half-width Home tile as the dashboard lays it out: header, figure
/// with goal and bar, one action.
Widget _tile(TrackerMetric metric, String value, String goal) => TrackerCard(
  metric: metric,
  status: TrackerStatus.done,
  statusLabel: 'Logged',
  onOpen: () {},
  actions: [
    TrackerQuickAction(
      label: 'Edit',
      icon: Icons.edit_rounded,
      color: metric.color,
      onTap: () {},
    ),
  ],
  child: TrackerProgress(
    value: value,
    goal: goal,
    fraction: 0.9,
    color: metric.color,
  ),
);

/// Same sizing as the dashboard's tile pairs.
class _Pair extends StatelessWidget {
  const _Pair();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(AppDimens.gutter),
      child: SizedBox(
        height: context.textScaled(AppDimens.dashboardTileHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _tile(TrackerMetric.sleep, '7h 56m', '8h 0m')),
            const SizedBox(width: AppDimens.cardGap),
            Expanded(child: _tile(TrackerMetric.water, '1.5 L', '2.5 L')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // Below the large-text point the tiles stay side by side.
  for (final width in [360.0, 412.0]) {
    for (final scale in [0.85, 1.0, 1.15]) {
      testWidgets('half tiles fit at ${width.toInt()} dp, $scale text', (
        tester,
      ) async {
        await pumpPage(
          tester,
          const _Pair(),
          textScale: scale,
          size: Size(width, 800),
        );
        await tester.pump();
        expect(takeAllExceptions(tester), isEmpty);
      });
    }
  }
}
