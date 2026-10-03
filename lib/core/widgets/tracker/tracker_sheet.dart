import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';

/// Layout of every tracker bottom sheet (log, goal, quick-log hub):
/// metric badge + title + close, hairline, body, then a pinned action.
class TrackerSheet extends StatelessWidget {
  final TrackerMetric? metric;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  const TrackerSheet({
    super.key,
    required this.title,
    required this.child,
    this.metric,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (metric != null) ...[
                  TrackerBadge(metric!),
                  const SizedBox(width: AppDimens.space12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.headlineSmall),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.vColors.grayText,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space12),
            Divider(
              height: AppDimens.borderThin,
              color: context.vColors.divider,
            ),
            const SizedBox(height: AppDimens.sectionGap),
            Flexible(child: SingleChildScrollView(child: child)),
            if (action != null) ...[
              const SizedBox(height: AppDimens.sectionGap),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Large tappable preset in a log sheet (a glass of water, a mood level).
class TrackerPresetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const TrackerPresetTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.caption,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    return Semantics(
      button: true,
      selected: selected,
      label: caption == null ? label : '$label, $caption',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: selected ? AppDimens.tintBorderAlpha : AppDimens.tintAlpha,
          ),
          borderRadius: radius,
          border: Border.all(
            color: selected
                ? color
                : color.withValues(alpha: AppDimens.tintBorderAlpha),
            width: selected ? AppDimens.borderThick : AppDimens.borderThin,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimens.trackerPreset,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space4,
                  vertical: AppDimens.space10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: AppDimens.iconLg, color: color),
                    const SizedBox(height: AppDimens.space4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: context.text.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (caption != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          caption!,
                          maxLines: 1,
                          style: context.text.labelSmall?.copyWith(
                            color: context.vColors.grayText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal-width row of [TrackerPresetTile]s.
class TrackerPresetRow extends StatelessWidget {
  final List<Widget> children;

  const TrackerPresetRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimens.space8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Opens the goal editor for [metric] and returns the saved value, or
/// null if dismissed. Values move in [step]s between [min] and [max];
/// [recommended] shows as a one-tap suggestion.
Future<double?> showTrackerGoalSheet({
  required BuildContext context,
  required TrackerMetric metric,
  required String title,
  required double initial,
  required double min,
  required double max,
  required double step,
  required String Function(double value) format,
  String? description,
  double? recommended,
  String? recommendedReason,
}) {
  return showAppBottomSheet<double>(
    context: context,
    builder: (_) => _GoalSheet(
      metric: metric,
      title: title,
      initial: initial.clamp(min, max).toDouble(),
      min: min,
      max: max,
      step: step,
      format: format,
      description: description,
      recommended: recommended,
      recommendedReason: recommendedReason,
    ),
  );
}

class _GoalSheet extends StatefulWidget {
  final TrackerMetric metric;
  final String title;
  final double initial;
  final double min;
  final double max;
  final double step;
  final String Function(double value) format;
  final String? description;
  final double? recommended;
  final String? recommendedReason;

  const _GoalSheet({
    required this.metric,
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    this.description,
    this.recommended,
    this.recommendedReason,
  });

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late double _value = widget.initial;

  void _set(double v) {
    HapticFeedback.selectionClick();
    setState(() => _value = v.clamp(widget.min, widget.max).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.metric.color;
    final recommended = widget.recommended;
    return TrackerSheet(
      metric: widget.metric,
      title: widget.title,
      subtitle: widget.description,
      action: AppPrimaryButton(
        label: 'Save goal',
        onTap: () => Navigator.pop(context, _value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Decrease',
                onPressed: _value > widget.min
                    ? () => _set(_value - widget.step)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.format(_value),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.metricLarge.copyWith(color: color),
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Increase',
                onPressed: _value < widget.max
                    ? () => _set(_value + widget.step)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: context.vColors.track,
            ),
            child: Slider(
              value: _value,
              min: widget.min,
              max: widget.max,
              divisions: ((widget.max - widget.min) / widget.step).round(),
              label: widget.format(_value),
              onChanged: _set,
            ),
          ),
          if (recommended != null) ...[
            const SizedBox(height: AppDimens.space8),
            AppCard(
              width: double.infinity,
              sheen: false,
              padding: AppDimens.cardPaddingCompact,
              onTap: () => _set(recommended),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: AppDimens.iconMd,
                    color: color,
                  ),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommended: ${widget.format(recommended)}',
                          style: context.text.titleSmall,
                        ),
                        if (widget.recommendedReason != null)
                          Text(
                            widget.recommendedReason!,
                            style: context.text.bodySmall?.copyWith(
                              color: context.vColors.grayText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'Use',
                    style: context.text.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
