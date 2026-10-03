import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// Where today stands against the goal. One vocabulary for every tracker,
/// shown as a [TrackerStatusChip] on home cards and detail heroes.
enum TrackerStatus {
  noGoal('Set a goal', Icons.flag_outlined),
  notLogged('Not logged', Icons.radio_button_unchecked_rounded),
  onTrack('On track', Icons.trending_up_rounded),
  behind('Behind', Icons.schedule_rounded),
  done('Goal met', Icons.check_circle_rounded),
  over('Over limit', Icons.warning_amber_rounded);

  final String label;
  final IconData icon;
  const TrackerStatus(this.label, this.icon);

  Color color(BuildContext context) {
    final v = context.vColors;
    return switch (this) {
      TrackerStatus.noGoal || TrackerStatus.notLogged => v.grayText!,
      TrackerStatus.onTrack => context.colors.primary,
      TrackerStatus.behind => v.warning!,
      TrackerStatus.done => v.success!,
      TrackerStatus.over => context.colors.error,
    };
  }

  /// Status of [value] against [goal] in the metric's [direction].
  ///
  /// For "reach at least" goals, [paceFraction] (0–1, share of the day that
  /// should be done by now) separates "On track" from "Behind"; without it
  /// any progress counts as on track.
  static TrackerStatus of({
    required double? value,
    required double? goal,
    GoalDirection direction = GoalDirection.up,
    double? paceFraction,
  }) {
    if (goal == null || goal <= 0) {
      return value == null ? TrackerStatus.notLogged : TrackerStatus.noGoal;
    }
    if (value == null) return TrackerStatus.notLogged;
    switch (direction) {
      case GoalDirection.up:
        if (value >= goal) return TrackerStatus.done;
        if (value <= 0) return TrackerStatus.notLogged;
        if (paceFraction != null && value < goal * paceFraction * 0.8) {
          return TrackerStatus.behind;
        }
        return TrackerStatus.onTrack;
      case GoalDirection.down:
        return value > goal ? TrackerStatus.over : TrackerStatus.onTrack;
      case GoalDirection.near:
        if ((value - goal).abs() <= goal * TrendSeries.nearTolerance) {
          return TrackerStatus.done;
        }
        return value > goal ? TrackerStatus.over : TrackerStatus.onTrack;
    }
  }

  /// Share of the waking day (7am–11pm) that has passed — the pace a daily
  /// "reach at least" goal should keep.
  static double dayPace([DateTime? now]) {
    final t = now ?? DateTime.now();
    final hours = t.hour + t.minute / 60;
    return ((hours - 7) / 16).clamp(0.0, 1.0);
  }
}

/// Pill with the status icon and label in the status colour.
class TrackerStatusChip extends StatelessWidget {
  final TrackerStatus status;

  /// Overrides the status label (e.g. "Very calm").
  final String? label;

  /// Overrides the status colour (e.g. a mood level colour).
  final Color? color;

  const TrackerStatusChip(this.status, {super.key, this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? status.color(context);
    return AnimatedContainer(
      duration: AppDurations.medium,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space8,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: AppDimens.tintAlpha),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(
          color: c.withValues(alpha: AppDimens.tintBorderAlpha),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: AppDimens.iconXs, color: c),
          const SizedBox(width: AppDimens.space4),
          Text(
            label ?? status.label,
            maxLines: 1,
            style: context.text.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
