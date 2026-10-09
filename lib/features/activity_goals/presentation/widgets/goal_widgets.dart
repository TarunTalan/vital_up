import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';

extension GoalMetricStyle on GoalMetric {
  IconData get icon => switch (this) {
    GoalMetric.steps => Icons.directions_walk_rounded,
    GoalMetric.distance => Icons.route_rounded,
    GoalMetric.calories => Icons.local_fire_department_rounded,
    GoalMetric.activeMinutes => Icons.timer_rounded,
    GoalMetric.workouts => Icons.fitness_center_rounded,
  };

  Color get color => switch (this) {
    GoalMetric.steps => AppColors.activitySteps,
    GoalMetric.distance => AppColors.activityDistance,
    GoalMetric.calories => AppColors.activityCalories,
    GoalMetric.activeMinutes => AppColors.activityMinutes,
    GoalMetric.workouts => AppColors.activityWorkouts,
  };

  /// Number only, e.g. "6,240" or "2.4".
  String format(double value) => switch (this) {
    GoalMetric.distance => value.toStringAsFixed(value < 10 ? 1 : 0),
    _ => NumberFormat.decimalPattern().format(value.round()),
  };

  /// Number with unit, e.g. "2.4 km".
  String formatWithUnit(double value) => '${format(value)} $unit';
}

/// Icon badge, name + window, progress bar and "current / target".
class GoalProgressRow extends StatelessWidget {
  final ActivityGoal goal;
  final double current;
  final double fraction;
  final bool selected;
  final VoidCallback? onTap;

  const GoalProgressRow({
    super.key,
    required this.goal,
    required this.current,
    required this.fraction,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final metric = goal.metric;
    final done = current >= goal.target;
    final grey = context.vColors.grayText;
    final row = Row(
      children: [
        AppIconBadge(color: metric.color, icon: Icon(metric.icon)),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  Text(
                    goal.period.windowLabel,
                    style: context.text.labelSmall?.copyWith(color: grey),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) =>
                    AppProgressBar(value: value, color: metric.color),
              ),
              const SizedBox(height: AppDimens.space4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${metric.format(current)} / ${metric.formatWithUnit(goal.target)}',
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ),
                  if (done)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: AppDimens.iconXs,
                          color: context.vColors.success,
                        ),
                        const SizedBox(width: AppDimens.space4),
                        Text(
                          'Done',
                          style: context.text.labelSmall?.copyWith(
                            color: context.vColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '${(fraction * 100).round()}%',
                      style: context.text.labelSmall?.copyWith(color: grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return AppCard(
      width: double.infinity,
      sheen: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space16,
        vertical: AppDimens.space12,
      ),
      borderColor: selected ? metric.color : null,
      onTap: onTap,
      child: row,
    );
  }
}

/// Add / edit a goal: metric chips, Daily / Weekly, target stepper.
/// Pops the saved [ActivityGoal], or `null`.
class GoalEditorSheet extends StatefulWidget {
  final ActivityGoal? initial;

  /// Ids of goals that already exist (can't be added twice).
  final Set<String> taken;
  final VoidCallback? onDelete;

  const GoalEditorSheet({
    super.key,
    this.initial,
    this.taken = const {},
    this.onDelete,
  });

  @override
  State<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<GoalEditorSheet> {
  late GoalMetric _metric = widget.initial?.metric ?? _firstFree().$1;
  late GoalPeriod _period = widget.initial?.period ?? _firstFree().$2;
  late double _target = _metric.clampTarget(
    _period,
    widget.initial?.target ?? _metric.suggested(_period),
  );

  bool get _editing => widget.initial != null;

  (GoalMetric, GoalPeriod) _firstFree() {
    for (final p in GoalPeriod.values) {
      for (final m in GoalMetric.values) {
        if (!widget.taken.contains('${m.name}_${p.name}')) return (m, p);
      }
    }
    return (GoalMetric.steps, GoalPeriod.daily);
  }

  bool _isTaken(GoalMetric m, GoalPeriod p) =>
      !_editing && widget.taken.contains('${m.name}_${p.name}');

  void _pick({GoalMetric? metric, GoalPeriod? period}) {
    setState(() {
      _metric = metric ?? _metric;
      _period = period ?? _period;
      _target = _metric.suggested(_period);
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _metric.step;
    final taken = _isTaken(_metric, _period);
    final actions = Row(
      children: [
        if (widget.onDelete != null) ...[
          Expanded(
            child: AppSecondaryButton(
              label: 'Delete',
              contentColor: context.colors.error,
              onTap: () {
                Navigator.pop(context);
                widget.onDelete!();
              },
            ),
          ),
          const SizedBox(width: AppDimens.space12),
        ],
        Expanded(
          child: AppPrimaryButton(
            label: 'Save goal',
            enabled: !taken,
            onTap: () => Navigator.pop(
              context,
              ActivityGoal(
                metric: _metric,
                period: _period,
                target: _metric.clampTarget(_period, _target),
              ),
            ),
          ),
        ),
      ],
    );
    return TrackerSheet(
      metric: TrackerMetric.activity,
      title: _editing ? 'Edit goal' : 'New goal',
      subtitle: 'Daily or weekly target',
      action: actions,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_editing) ...[
            Text('Track', style: context.text.titleSmall),
            const SizedBox(height: AppDimens.space8),
            Wrap(
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space8,
              children: [
                for (final m in GoalMetric.values)
                  ChoiceChip(
                    avatar: Icon(
                      m.icon,
                      size: AppDimens.iconXs,
                      color: m.color,
                    ),
                    label: Text(m.label),
                    selected: _metric == m,
                    showCheckmark: false,
                    onSelected: (_) => _pick(metric: m),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.cardInnerGap),
            SegmentedButton<GoalPeriod>(
              showSelectedIcon: false,
              segments: [
                for (final p in GoalPeriod.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_period},
              onSelectionChanged: (s) => _pick(period: s.first),
            ),
            const SizedBox(height: AppDimens.cardInnerGap),
          ],
          Text('${_period.label} target', style: context.text.titleSmall),
          const SizedBox(height: AppDimens.space8),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Decrease',
                onPressed: _target - step >= _metric.minTarget(_period)
                    ? () => setState(
                          () => _target =
                              _metric.clampTarget(_period, _target - step),
                        )
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _metric.formatWithUnit(_target),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.metricLarge.copyWith(
                      color: _metric.color,
                    ),
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Increase',
                onPressed: _target + step <= _metric.maxTarget(_period)
                    ? () => setState(
                          () => _target =
                              _metric.clampTarget(_period, _target + step),
                        )
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (taken) ...[
            const SizedBox(height: AppDimens.space12),
            const AppInfoNote(
              message: 'You already have this goal — edit it from the list.',
            ),
          ],
        ],
      ),
    );
  }
}
