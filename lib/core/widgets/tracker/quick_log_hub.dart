import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';

/// What the person picked in the quick-log hub.
sealed class QuickLogChoice {
  const QuickLogChoice();
}

class QuickLogMetric extends QuickLogChoice {
  final TrackerMetric metric;
  const QuickLogMetric(this.metric);
}

class QuickLogGoals extends QuickLogChoice {
  const QuickLogGoals();
}

/// One place to log anything: a grid of every manually logged metric, plus
/// a shortcut to the goals list. Returns the choice once the sheet closes,
/// so the caller opens the matching log sheet from its own context.
Future<QuickLogChoice?> showQuickLogHub(BuildContext context) {
  return showAppBottomSheet<QuickLogChoice>(
    context: context,
    builder: (_) => const _QuickLogHub(),
  );
}

class _QuickLogHub extends StatelessWidget {
  const _QuickLogHub();

  static const _columns = 3;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      for (final m in TrackerMetric.values)
        if (!m.isAutoTracked) m,
    ];
    return TrackerSheet(
      title: 'Log something',
      subtitle: 'Pick what you want to record',
      action: AppSecondaryButton(
        label: 'Manage goals',
        leadingIcon: const Icon(Icons.flag_rounded),
        onTap: () => Navigator.pop(context, const QuickLogGoals()),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              (constraints.maxWidth - AppDimens.space8 * (_columns - 1)) /
              _columns;
          return Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: [
              for (final m in metrics)
                SizedBox(
                  width: width,
                  child: _HubTile(
                    metric: m,
                    onTap: () => Navigator.pop(context, QuickLogMetric(m)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final TrackerMetric metric;
  final VoidCallback onTap;

  const _HubTile({required this.metric, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: metric.logLabel,
      excludeSemantics: true,
      child: AppCard(
        sheen: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space8,
          vertical: AppDimens.space12,
        ),
        onTap: onTap,
        child: SizedBox(
          height: AppDimens.trackerTile - AppDimens.space24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TrackerBadge(metric),
              const SizedBox(height: AppDimens.space8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  metric.logLabel,
                  maxLines: 1,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
