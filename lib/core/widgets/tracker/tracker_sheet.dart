import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/goal_controls.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/value_ruler.dart';

/// Layout of every tracker bottom sheet (log, goal, quick-log hub):
/// metric badge + title + close, hairline, body, then a pinned action.
/// The body scrolls when it's taller than the room; with [scrollable]
/// false it gets the room left instead, for a body that sizes itself to
/// fit (the sleep clock), so nothing ever hides behind the action.
class TrackerSheet extends StatelessWidget {
  final TrackerMetric? metric;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final bool scrollable;

  const TrackerSheet({
    super.key,
    required this.title,
    required this.child,
    this.metric,
    this.subtitle,
    this.action,
    this.scrollable = true,
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
            Flexible(
              child: scrollable ? SingleChildScrollView(child: child) : child,
            ),
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
                    FitText(
                      label,
                      maxLines: 1,
                      style: context.text.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (caption != null)
                      FitText(
                        caption!,
                        maxLines: 1,
                        style: context.text.labelSmall?.copyWith(
                          color: context.vColors.grayText,
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
/// [recommended] shows as a one-tap suggestion. With [onRemove] (the user
/// has a goal) a "Remove goal" button asks first, saying [removeMessage]
/// (what changes without the goal), runs it and closes with null.
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
  Future<void> Function()? onRemove,
  String? removeMessage,
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
      onRemove: onRemove,
      removeMessage: removeMessage,
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
  final Future<void> Function()? onRemove;
  final String? removeMessage;

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
    this.onRemove,
    this.removeMessage,
  });

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late double _value = widget.initial;
  bool _removing = false;

  Future<void> _remove(Future<void> Function() onRemove) async {
    final metric = widget.metric.label.toLowerCase();
    final confirmed = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove your $metric goal?'),
        content: Text(
          widget.removeMessage ??
              'You can keep logging and set a goal again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      await onRemove();
    } catch (e) {
      debugPrint('Goal not removed: $e');
      if (!mounted) return;
      setState(() => _removing = false);
      showErrorSnackBar(context, "Couldn't remove your goal. Try again.");
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  /// From the +/- buttons and presets: the same selection click the
  /// sliders and the ruler give per step.
  void _set(double v) {
    final next = v.clamp(widget.min, widget.max).toDouble();
    if (next != _value) {
      HapticFeedback.selectionClick();
      setState(() => _value = next);
    }
  }

  /// From the ruler or a goal control, which give their own sound and
  /// vibration per step.
  void _setQuietly(double v) {
    final next = v.clamp(widget.min, widget.max).toDouble();
    if (next != _value) setState(() => _value = next);
  }

  List<double> _quickPresets(TrackerMetric metric) {
    final list = switch (metric) {
      TrackerMetric.water => [1500.0, 2000.0, 2500.0, 3000.0],
      TrackerMetric.sleep => [420.0, 450.0, 480.0, 510.0, 540.0],
      TrackerMetric.screenTime => [60.0, 90.0, 120.0, 150.0, 180.0],
      _ => const <double>[],
    };
    return list.where((p) => p >= widget.min && p <= widget.max).toList();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.metric.color;
    final recommended = widget.recommended;
    final presets = _quickPresets(widget.metric);
    return TrackerSheet(
      metric: widget.metric,
      title: widget.title,
      subtitle: widget.description,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPrimaryButton(
            label: 'Save goal',
            enabled: !_removing,
            onTap: () => Navigator.pop(context, _value),
          ),
          if (widget.onRemove case final onRemove?) ...[
            const SizedBox(height: AppDimens.space8),
            TextButton(
              onPressed: _removing ? null : () => _remove(onRemove),
              style: TextButton.styleFrom(
                foregroundColor: context.vColors.accentText,
              ),
              child: const Text('Remove goal'),
            ),
          ],
        ],
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
                child: FitText(
                  widget.format(_value),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.metricLarge.copyWith(color: color),
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
          if (widget.metric == TrackerMetric.weight) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
              child: ValueRuler(
                value: _value,
                min: widget.min,
                max: widget.max,
                step: widget.step,
                color: color,
                semanticValue: widget.format,
                onChanged: _setQuietly,
              ),
            ),
          ] else if (widget.metric == TrackerMetric.water) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
              child: WaterGoalGauge(
                value: _value,
                min: widget.min,
                max: widget.max,
                step: widget.step,
                onChanged: _setQuietly,
              ),
            ),
          ] else if (widget.metric == TrackerMetric.sleep) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
              child: SleepGoalDial(
                value: _value,
                min: widget.min,
                max: widget.max,
                step: widget.step,
                onChanged: _setQuietly,
              ),
            ),
          ] else if (widget.metric == TrackerMetric.screenTime) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
              child: ScreenTimeGoalGauge(
                value: _value,
                min: widget.min,
                max: widget.max,
                step: widget.step,
                onChanged: _setQuietly,
              ),
            ),
          ] else ...[
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
          ],
          if (presets.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space12),
            Wrap(
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space8,
              children: [
                for (final p in presets)
                  GoalPresetChip(
                    label: widget.format(p),
                    color: color,
                    selected: (_value - p).abs() < widget.step / 2,
                    onTap: () => _set(p),
                  ),
              ],
            ),
          ],
          if (recommended != null) ...[
            const SizedBox(height: AppDimens.space8),
            AppCard(
              width: double.infinity,
              sheen: false,
              padding: AppDimens.cardPaddingCompact,
              onTap: () => _set(recommended),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/nav/vita.svg',
                    width: AppDimens.iconMd,
                    height: AppDimens.iconMd,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
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

/// A quick pick in the goal sheet: a quiet outlined pill; selected, it takes
/// a light tint of the metric's [color] and a hairline of it, with the
/// label staying in the readable text colour.
class GoalPresetChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const GoalPresetChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final radius = BorderRadius.circular(AppDimens.radiusPill);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: AppDimens.tintAlpha)
              : Colors.transparent,
          borderRadius: radius,
          border: Border.all(
            color: selected
                ? color.withValues(alpha: AppDimens.tintBorderAlpha * 2)
                : v.divider!,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimens.goalPresetHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space16,
                  vertical: AppDimens.space6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: context.text.bodyMedium?.copyWith(
                        color: selected ? context.colors.onSurface : v.grayText,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
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
